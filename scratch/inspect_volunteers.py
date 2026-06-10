import firebase_admin
from firebase_admin import credentials, firestore

try:
    cred = credentials.Certificate("android/app/google-services.json")
    firebase_admin.initialize_app(cred)
except Exception:
    # Fallback to default credentials if already initialized
    pass

db = firestore.client()
volunteers_ref = db.collection('volunteers')
docs = volunteers_ref.stream()

print("--- VOLUNTEERS IN FIRESTORE ---")
for doc in docs:
    data = doc.to_dict()
    print(f"ID: {doc.id}")
    print(f"Name: {data.get('displayName') or data.get('name')}")
    print(f"Speciality: {data.get('speciality')}")
    print(f"Specializations: {data.get('specializations')}")
    print(f"Status: {data.get('status')}")
    print(f"CurrentMissionId: {data.get('currentMissionId')}")
    print("-" * 30)
