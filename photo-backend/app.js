const express = require("express");
const mysql = require("mysql2");
const AWS = require("aws-sdk");
const multer = require("multer");
const cors = require("cors");
require("dotenv").config();

const app = express();
app.use(express.json());
app.use(cors());

// AWS S3 configuration
const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION,
});

// MySQL connection
const db = mysql.createConnection({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
});

db.connect((err) => {
  if (err) throw err;
  console.log("✅ MySQL Connected");
});

// Multer config for file upload
const storage = multer.memoryStorage();
const upload = multer({ storage });

// Upload photo endpoint
app.post("/upload", upload.single("photo"), (req, res) => {
  if (!req.file) return res.status(400).send("No file uploaded.");

  const params = {
    Bucket: process.env.AWS_BUCKET_NAME,
    Key: Date.now() + "-" + req.file.originalname,
    Body: req.file.buffer,
    ContentType: req.file.mimetype,
  };

  s3.upload(params, (err, data) => {
    if (err) return res.status(500).send("Error uploading to S3");

    const sql = "INSERT INTO photos (filename, url) VALUES (?, ?)";
    db.query(sql, [req.file.originalname, data.Location], (err, result) => {
      if (err) return res.status(500).send("DB Error");
      res.send({ message: "✅ Uploaded Successfully", url: data.Location });
    });
  });
});

// Get all photos
app.get("/photos", (req, res) => {
  db.query("SELECT * FROM photos ORDER BY created_at DESC", (err, results) => {
    if (err) return res.status(500).send("DB Error");
    res.send(results);
  });
});

// Delete photo
app.delete("/photos/:id", (req, res) => {
  const { id } = req.params;
  db.query("SELECT * FROM photos WHERE id = ?", [id], (err, results) => {
    if (err || results.length === 0) return res.status(404).send("Not found");
    const photo = results[0];
    const key = photo.url.split("/").pop();

    s3.deleteObject({ Bucket: process.env.AWS_BUCKET_NAME, Key: key }, (err) => {
      if (err) return res.status(500).send("S3 delete failed");

      db.query("DELETE FROM photos WHERE id = ?", [id], (err2) => {
        if (err2) return res.status(500).send("DB delete failed");
        res.send({ message: "✅ Photo deleted successfully" });
      });
    });
  });
});

app.listen(process.env.PORT || 3000, () =>
  console.log(`🚀 Server running on port ${process.env.PORT}`)
);
