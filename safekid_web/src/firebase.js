import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyCBrlaQ_inJDQOdtAKMmkLjyawiUovp7d4",
  authDomain: "safekid-pro.firebaseapp.com",
  projectId: "safekid-pro",
  storageBucket: "safekid-pro.firebasestorage.app",
  messagingSenderId: "510126692584",
  appId: "1:510126692584:web:cb374d586abe3f9b1bd15d",
  measurementId: "G-8FBZ2DN15Q"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
