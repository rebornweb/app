-- Users table: stores user info
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(200) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL
);

-- Documents table: stores document info
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- Signers table: links documents to potential signers
CREATE TABLE signers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE
);

-- Signature fields table: stores signature fields for documents
CREATE TABLE signature_fields (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
    field_name VARCHAR(200) NOT NULL,
    required_signatures INT NOT NULL
);

-- Signatures table: stores actual signatures
CREATE TABLE signatures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    signature_field_id UUID REFERENCES signature_fields(id) ON DELETE CASCADE,
    signer_id UUID REFERENCES signers(id) ON DELETE CASCADE,
    signed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    signature_data TEXT NOT NULL
);

-- Keeps track of which signers have signed which fields
CREATE TABLE signature_field_signers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    signature_field_id UUID REFERENCES signature_fields(id) ON DELETE CASCADE,
    signer_id UUID REFERENCES signers(id) ON DELETE CASCADE,
    signed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    signature_data TEXT NOT NULL
);

-- Tracks the overall status of document signatures
CREATE TABLE document_status (
    document_id UUID PRIMARY KEY REFERENCES documents(id) ON DELETE CASCADE,
    is_fully_signed BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Function to update document status when signatures are added
CREATE OR REPLACE FUNCTION update_document_status() RETURNS TRIGGER AS $$
BEGIN
    -- Check if all required signatures for all fields are collected
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

-- Trigger to update document status when signatures are added
CREATE TRIGGER update_document_status_trigger
AFTER INSERT OR DELETE ON signature_field_signers
FOR EACH ROW EXECUTE FUNCTION update_document_status();
