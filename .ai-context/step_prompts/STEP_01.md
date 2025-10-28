### AI Agent Prompt

**Your Role:** You are a senior backend developer specializing in containerized application deployment.

**Your Objective:** Your task is to generate the complete file contents required to complete **Step 1: "Initialize Backend Services with Docker Compose"** as outlined in the `.ai-context/04_PROJECT_PLAN.md`.

You must adhere strictly to the details provided in the `.ai-context/01_TECHNICAL_SPEC.md` and the project plan.

---

### **Primary Instructions**

Based on the provided project documents, generate the full contents for the following three files:

1.  `backend/docker-compose.yml`
2.  `backend/api/Dockerfile`
3.  `backend/.env`

---

### **Detailed Requirements & Context**

#### **1. For `backend/docker-compose.yml`:**

*   **Define Three Services:**
    *   `api`: The Dart Shelf application. This service should be built from the `Dockerfile` located in `backend/api/`.
    *   `db`: The PostgreSQL database. Use the official `postgres:15` image as specified in the tech stack.
    *   `auth`: The PocketBase authentication service. Use a suitable public image like `uchp/pocketbase`.
*   **Data Persistence:**
    *   The `db` service **must** have a named volume to persist its data (e.g., `pgdata:/var/lib/postgresql/data`).
    *   The `auth` service **must** have a named volume to persist its data (e.g., `pbdata:/pb_data`).
*   **Environment Variables:**
    *   The `db` service must load its credentials (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`) from the `.env` file.
    *   The `api` service should also have access to the environment variables for database connection.
*   **Networking & Ports:**
    *   The services should be on the same network so they can communicate.
    *   Expose the necessary ports. For now, you can map the API's port (e.g., `8080:8080`) and PocketBase's port (e.g., `8090:8090`) to the host.
*   **Dependencies:** The `api` service should depend on the `db` and `auth` services to ensure a correct startup order.

#### **2. For `backend/api/Dockerfile`:**

*   **Multi-Stage Build:** This is a critical requirement.
    *   **Build Stage:** Start from the official `google/dart` SDK image. Set the working directory, copy `pubspec.yaml`, run `dart pub get`, copy the rest of the application source, and run `dart compile exe bin/server.dart -o bin/server`.
    *   **Runtime Stage:** Start from a minimal base image (e.g., `scratch` or a lean debian-based image). Copy the compiled executable from the build stage into the final image. Expose the application port (e.g., 8080) and define the `CMD` to run the executable.

#### **3. For `backend/.env`:**

*   **Purpose:** This file will store secrets and configuration, and it should **not** be committed to version control.
*   **Content:** Provide placeholder values for the PostgreSQL credentials that will be used by the `docker-compose.yml` file.
    *   `POSTGRES_DB=main_db`
    *   `POSTGRES_USER=admin`
    *   `POSTGRES_PASSWORD=your_secure_password_here`
