# Intention Mobile API V1

Base URL:

`https://www.intentiontest.helioho.st/api/v1/mobile/`

## 1. Database upgrade

Import once into the current database:

`database/mobile-api-v1-upgrade.sql`

No existing tables/data are deleted.

## 2. Authentication

### POST `auth/login`

JSON:

```json
{
  "login": "student-login",
  "password": "password",
  "device_name": "Samsung A55"
}
```

Response contains a Bearer token. Store it in secure device storage. The database stores only its SHA-256 hash.

For authenticated calls send:

`Authorization: Bearer im1_...`

Token lifetime: 30 days. `auth/logout` revokes the current token.

### POST `auth/logout`
### GET `me`
### GET `health` (public)

## 3. Common data

- GET `grading-scale`
- POST `telegram/link` (student)
- POST `telegram/unlink` (student)
- GET `classes`
- GET `classes/{class_id}/students`

Access to class/student data is restricted by role and current assignments.

## 4. Student test flow

- GET `tests`
- GET `tests/{test_id}`
- POST `attempt/start` JSON `{ "test_id": 12 }`
- GET `attempt/{attempt_id}`
- POST `attempt/{attempt_id}/answer`
- POST `attempt/{attempt_id}/finish`
- GET `results`

Choice answer example:

```json
{
  "question_id": 88,
  "option_id": 350
}
```

Short answer example:

```json
{
  "question_id": 89,
  "text_answer": "100"
}
```

Correct answers are not returned while an attempt is active.

## 5. Assistant attendance

- GET `attendance/summary?date=2026-09-22`
- GET `attendance?class_id=7&date=2026-09-22`
- POST `attendance/save`
- POST `attendance/send` JSON `{ "class_id": 7, "date": "2026-09-22", "target": "channel" }`

Example:

```json
{
  "class_id": 7,
  "date": "2026-09-22",
  "items": [
    {"student_id": 101, "status": "present", "note": ""},
    {"student_id": 102, "status": "absent", "note": "Сабабли"},
    {"student_id": 103, "status": "late", "note": "08:20"}
  ]
}
```

Allowed statuses: `present`, `absent`, `late`.

Only an assistant assigned to that class may save daily attendance. Teachers may read assistant attendance for their assigned classes.

## 6. Teacher journal

- GET `journal/assignments`
- GET `journal?class_id=7&subject_id=2&date=2026-09-22&period_no=1`
- POST `journal/save`
- GET `journal/history?limit=100`

Example save:

```json
{
  "class_id": 7,
  "subject_id": 2,
  "date": "2026-09-22",
  "period_no": 1,
  "topic": "Newton laws",
  "items": [
    {"student_id": 101, "attendance_status": "present", "grade": 5, "note": ""},
    {"student_id": 102, "attendance_status": "present", "grade": 4, "note": ""},
    {"student_id": 103, "attendance_status": "absent", "grade": null, "note": ""}
  ]
}
```

The response shows assistant daily attendance and teacher lesson attendance separately. The teacher can mark `present` even when the assistant marked the student `absent` earlier that day.

## 7. Response format

Success:

```json
{"ok":true,"data":{}}
```

Error:

```json
{"ok":false,"error":{"message":"...","code":422}}
```

Native Android/iOS applications do not need browser CORS. This API intentionally does not enable wildcard CORS.
