import React, { useState, useEffect } from "react";
import axios from "axios";
import { FaCloudUploadAlt, FaTrashAlt } from "react-icons/fa";
import "./index.css";

function App() {
  const [photos, setPhotos] = useState([]);
  const [selectedFile, setSelectedFile] = useState(null);
  const [loading, setLoading] = useState(false);
  const BACKEND_URL = process.env.REACT_APP_API_URL;

  const fetchPhotos = async () => {
    const res = await axios.get(`${BACKEND_URL}/photos`);
    setPhotos(res.data);
  };

  useEffect(() => {
    fetchPhotos();
  }, []);

  const uploadPhoto = async (e) => {
    e.preventDefault();
    if (!selectedFile) return alert("Select a photo!");
    const formData = new FormData();
    formData.append("photo", selectedFile);
    setLoading(true);
    await axios.post(`${BACKEND_URL}/upload`, formData);
    setLoading(false);
    fetchPhotos();
  };

  const deletePhoto = async (id) => {
    if (!window.confirm("Delete this photo?")) return;
    await axios.delete(`${BACKEND_URL}/photos/${id}`);
    fetchPhotos();
  };

  return (
    <div className="min-h-screen bg-gradient-to-r from-purple-600 via-pink-500 to-orange-400 p-6">
      <div className="text-center text-white text-4xl font-bold mb-6">📸 Photo Sharing App</div>
      <form onSubmit={uploadPhoto} className="flex justify-center gap-4 mb-8">
        <input type="file" onChange={(e) => setSelectedFile(e.target.files[0])}
               className="p-2 bg-white rounded-lg" />
        <button type="submit"
                disabled={loading}
                className="bg-yellow-400 hover:bg-yellow-500 text-black font-semibold px-4 py-2 rounded-xl">
          <FaCloudUploadAlt className="inline-block mr-2" />
          {loading ? "Uploading..." : "Upload"}
        </button>
      </form>

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
        {photos.map((p) => (
          <div key={p.id} className="relative group overflow-hidden rounded-xl shadow-lg">
            <img src={p.url} alt={p.filename} className="w-full h-64 object-cover" />
            <button onClick={() => deletePhoto(p.id)}
                    className="absolute top-2 right-2 bg-red-500 text-white p-2 rounded-full opacity-0 group-hover:opacity-100 transition">
              <FaTrashAlt />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

export default App;
