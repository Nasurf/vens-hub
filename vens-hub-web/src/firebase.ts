import { initializeApp } from 'firebase/app'
import {
  getAuth,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  signOut as firebaseSignOut,
  onAuthStateChanged,
  type User,
} from 'firebase/auth'

const firebaseConfig = {
  apiKey: 'AIzaSyA9b4G4B-IXUH9zwfLh_cI3G3kx7c8H10I',
  authDomain: 'vens-hub.firebaseapp.com',
  projectId: 'vens-hub',
  storageBucket: 'vens-hub.firebasestorage.app',
  messagingSenderId: '617771520988',
  appId: '1:617771520988:web:bf365c8a1c2608aacfb519',
  measurementId: 'G-KGFF3NWEXQ',
}

const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)
const googleProvider = new GoogleAuthProvider()

export function onAuthChange(callback: (user: User | null) => void) {
  return onAuthStateChanged(auth, callback)
}

export async function loginWithEmail(email: string, password: string) {
  const result = await signInWithEmailAndPassword(auth, email, password)
  return result.user
}

export async function registerWithEmail(email: string, password: string) {
  const result = await createUserWithEmailAndPassword(auth, email, password)
  return result.user
}

export async function loginWithGoogle() {
  const result = await signInWithPopup(auth, googleProvider)
  return result.user
}

export async function signOutUser() {
  await firebaseSignOut(auth)
}

export function getUserIdHeader(user: User | null): Record<string, string> {
  if (!user) return {}
  return { 'X-User-Id': user.uid }
}
