# blog-react-ui

Tiny React UI (Vite) that uses the backend JSON API:

- `GET /api/posts`
- `POST /api/posts`

## Run

1) Start the backend (Tomcat):

- build the WAR: `mvn -q -DskipTests package`
- run via Dockerfile.web or deploy into your Tomcat

2) Start React dev server:

```bash
cd react-ui
npm install
npm run dev
```

The dev server proxies `/api` to `http://localhost:8080`.
