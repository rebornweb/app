
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(200) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL
);


CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL
);


CREATE TABLE signers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE
);


CREATE TABLE signature_fields (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
    field_name VARCHAR(200) NOT NULL,
    required_signatures INT NOT NULL
);


CREATE TABLE signatures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    signature_field_id UUID REFERENCES signature_fields(id) ON DELETE CASCADE,
    signer_id UUID REFERENCES signers(id) ON DELETE CASCADE,
    signed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    signature_data TEXT NOT NULL
);


CREATE TABLE signature_field_signers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    signature_field_id UUID REFERENCES signature_fields(id) ON DELETE CASCADE,
    signer_id UUID REFERENCES signers(id) ON DELETE CASCADE,
    signed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    signature_data TEXT NOT NULL
);

CREATE TABLE document_status (
    document_id UUID PRIMARY KEY REFERENCES documents(id) ON DELETE CASCADE,
    is_fully_signed BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE OR REPLACE FUNCTION update_document_status() RETURNS TRIGGER AS $$
BEGIN
 
    IF (
        SELECT COUNT(*) = 0
        FROM signature_fields sf
        LEFT JOIN (
            SELECT signature_field_id, COUNT(*) as signatures_collected
            FROM signature_field_signers
            GROUP BY signature_field_id
        ) sfs ON sf.id = sfs.signature_field_id
        WHERE sf.required_signatures > COALESCE(sfs.signatures_collected, 0)
    ) THEN
        UPDATE document_status
        SET is_fully_signed = TRUE,
            updated_at = CURRENT_TIMESTAMP
        WHERE document_id = NEW.document_id;
    ELSE
        UPDATE document_status
        SET is_fully_signed = FALSE,
            updated_at = CURRENT_TIMESTAMP
        WHERE document_id = NEW.document_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER update_document_status_trigger
AFTER INSERT OR DELETE ON signature_field_signers
FOR EACH ROW EXECUTE FUNCTION update_document_status();
