const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const port = 5000;

// Configure PostgreSQL connection
const pool = new Pool({
    user: 'mynewuser',
    host: 'localhost',
    database: 'mydatabase',
    password: 'secretpassword',
    port: 5432,
});

app.use(cors());
app.use(bodyParser.json());

// Endpoint to get all users
app.get('/api/users', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM users');
        res.json(result.rows);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server error');
    }
});

// Endpoint to create a new user
app.post('/api/users', async (req, res) => {
    const { email, name } = req.body;
    try {
        const result = await pool.query(
            'INSERT INTO users (email, name) VALUES ($1, $2) RETURNING *',
            [email, name]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server error');
    }
});

// More endpoints can be added for documents, signers, signatures...

app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
