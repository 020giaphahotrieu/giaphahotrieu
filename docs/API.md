# API Documentation

Base URL: `http://localhost:4000/api`

Response chuẩn:

```json
{
  "success": true,
  "message": "Success",
  "data": {}
}
```

Error chuẩn:

```json
{
  "success": false,
  "message": "Error message",
  "errors": []
}
```

## Auth

- `POST /auth/login` với `{ "email": "admin@example.com", "password": "Admin@123456" }`
- `POST /auth/register`
- `GET /auth/me` cần `Authorization: Bearer <token>`

## Core

- `GET /dashboard`
- `GET /families`
- `GET /members`
- `POST /members`
- `GET /members/:id`
- `DELETE /members/:id?force=true`
- `GET /relationships`
- `GET /events`
- `POST /media/upload`
- `GET /analytics`
- `GET /export`
- `POST /backup`
