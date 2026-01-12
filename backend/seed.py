import requests

BASE_URL = "http://127.0.0.1:8000/api/v1"

users = [
    # Admins (2)
    {
        "email": "admin1@example.com",
        "name": "Admin One",
        "password": "securetest123",
        "role": "ADMIN",
        "age_group": 0,
    },
    {
        "email": "admin2@example.com",
        "name": "Admin Two",
        "password": "securetest123",
        "role": "ADMIN",
        "age_group": 0,
    },
    # Teachers (6)
    {
        "email": "teacher.addis1@example.com",
        "name": "Teacher Addis One",
        "password": "securetest123",
        "role": "TEACHER",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    {
        "email": "teacher.addis2@example.com",
        "name": "Teacher Addis Two",
        "password": "securetest123",
        "role": "TEACHER",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    {
        "email": "teacher.bahir@example.com",
        "name": "Teacher Bahir",
        "password": "securetest123",
        "role": "TEACHER",
        "city": "Bahir Dar",
        "age_group": 0,
    },
    {
        "email": "teacher.mekelle@example.com",
        "name": "Teacher Mekelle",
        "password": "securetest123",
        "role": "TEACHER",
        "city": "Mekelle",
        "age_group": 0,
    },
    {
        "email": "teacher.jimma@example.com",
        "name": "Teacher Jimma",
        "password": "securetest123",
        "role": "TEACHER",
        "city": "Jimma",
        "age_group": 0,
    },
    {
        "email": "teacher.hawassa@example.com",
        "name": "Teacher Hawassa",
        "password": "securetest123",
        "role": "TEACHER",
        "city": "Hawassa",
        "age_group": 0,
    },
    # Students Group 1: Addis Ababa, ABC School, Grade 5
    {
        "email": "student1@example.com",
        "name": "Abebe Kebede",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 5,
        "school": "ABC School",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    {
        "email": "student2@example.com",
        "name": "Almaz Tadesse",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 5,
        "school": "ABC School",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    {
        "email": "student3@example.com",
        "name": "Bekele Lemma",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 5,
        "school": "ABC School",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    {
        "email": "student4@example.com",
        "name": "Chaltu Worku",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 5,
        "school": "ABC School",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    {
        "email": "student5@example.com",
        "name": "Dawit Solomon",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 5,
        "school": "ABC School",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    # Group 2: Addis Ababa, DEF School, Grade 6
    {
        "email": "student6@example.com",
        "name": "Elias Getachew",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 6,
        "school": "DEF School",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    {
        "email": "student7@example.com",
        "name": "Fikirte Mengistu",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 6,
        "school": "DEF School",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    {
        "email": "student8@example.com",
        "name": "Getu Haile",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 6,
        "school": "DEF School",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    {
        "email": "student9@example.com",
        "name": "Hana Assefa",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 6,
        "school": "DEF School",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    # Group 3: Bahir Dar, GHI School, Grade 7
    {
        "email": "student10@example.com",
        "name": "Issa Mohammed",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 7,
        "school": "GHI School",
        "city": "Bahir Dar",
        "age_group": 0,
    },
    {
        "email": "student11@example.com",
        "name": "Jemila Ahmed",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 7,
        "school": "GHI School",
        "city": "Bahir Dar",
        "age_group": 0,
    },
    {
        "email": "student12@example.com",
        "name": "Kiros Tesfaye",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 7,
        "school": "GHI School",
        "city": "Bahir Dar",
        "age_group": 0,
    },
    {
        "email": "student13@example.com",
        "name": "Liya Berhanu",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 7,
        "school": "GHI School",
        "city": "Bahir Dar",
        "age_group": 0,
    },
    # Mixed Group
    {
        "email": "student14@example.com",
        "name": "Mikael Yohannes",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 5,
        "school": "JKL School",
        "city": "Addis Ababa",
        "age_group": 0,
    },
    {
        "email": "student15@example.com",
        "name": "Naomi Daniel",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 6,
        "school": "ABC School",
        "city": "Mekelle",
        "age_group": 0,
    },
    {
        "email": "student16@example.com",
        "name": "Omar Farah",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 8,
        "school": "MNO School",
        "city": "Jimma",
        "age_group": 0,
    },
    {
        "email": "student17@example.com",
        "name": "Sara Teshome",
        "password": "securetest123",
        "role": "STUDENT",
        "grade_level": 4,
        "school": "PQR School",
        "city": "Hawassa",
        "age_group": 0,
    },
]


def create_users():
    for user in users:
        response = requests.post(f"{BASE_URL}/users/", json=user)
        if response.status_code in (200, 201):
            print(f"✓ Created {user['email']}")
        else:
            print(f"✗ Failed {user['email']}: {response.status_code} {response.text}")


if __name__ == "__main__":
    print("Starting seed script...")
    create_users()
    print("Seed complete!")
