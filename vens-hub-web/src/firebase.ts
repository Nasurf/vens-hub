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
  apiKey: 'AIzaSyA9b4G4B-IXUH9zwfLh_cI3G3kx7c8H10I',
  authDomain: 'vens-hub.firebaseapp.com',
  projectId: 'vens-hub',
  storageBucket: 'vens-hub.firebasestorage.app',
  messagingSenderId: '617771520988',
  appId: '1:617771520988:web:bf365c8a1c2608aacfb519',
  measurementId: 'G-KGFF3NWEXQ',
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
