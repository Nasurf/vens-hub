import { initializeApp } from 'firebase/app'
import {
  getAuth,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  signOut as firebaseSignOut,
  onAuthStateChanged,
  updateProfile,
  type User,
} from 'firebase/auth'

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
  measurementId: import.meta.env.VITE_FIREBASE_MEASUREMENT_ID,
}

const looksLikeRealKey = Boolean(
  firebaseConfig.apiKey &&
    firebaseConfig.apiKey.length > 20 &&
    !firebaseConfig.apiKey.includes('...') &&
    firebaseConfig.apiKey.startsWith('AIza')
)

export const hasFirebaseConfig = Boolean(
  looksLikeRealKey &&
    firebaseConfig.authDomain &&
    firebaseConfig.projectId &&
    firebaseConfig.appId,
)

const app = hasFirebaseConfig ? initializeApp(firebaseConfig) : null
export const auth = app ? getAuth(app) : null
const googleProvider = app ? new GoogleAuthProvider() : null

export function onAuthChange(callback: (user: User | null) => void) {
  if (!auth) {
    callback(null)
    return () => {}
  }
  return onAuthStateChanged(auth, callback)
}

export async function loginWithEmail(email: string, password: string) {
  if (!auth) throw new Error('Firebase Auth is not configured')
  const result = await signInWithEmailAndPassword(auth, email, password)
  return result.user
}

export async function registerWithEmail(email: string, password: string, displayName?: string) {
  if (!auth) throw new Error('Firebase Auth is not configured')
  const result = await createUserWithEmailAndPassword(auth, email, password)
  if (displayName && result.user) {
    await updateProfile(result.user, { displayName })
  }
  return result.user
}

export async function loginWithGoogle() {
  if (!auth || !googleProvider) throw new Error('Firebase Auth is not configured')
  const result = await signInWithPopup(auth, googleProvider)
  return result.user
}

export async function signOutUser() {
  if (!auth) return
  await firebaseSignOut(auth)
}

export function getUserIdHeader(user: User | null): Record<string, string> {
  if (!user) return {}
  return { 'X-User-Id': user.uid }
}
