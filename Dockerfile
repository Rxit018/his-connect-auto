# --- Stage 1: Builder ---
# ใช้ image ที่มี Rust และ toolchain ครบ (Alpine variant จะเล็กกว่า)
FROM rust:1-alpine AS builder

WORKDIR /usr/src/app

# ติดตั้ง C libraries ที่จำเป็น (ถ้ามี) เช่น openssl
# RUN apk add --no-cache musl-dev openssl-dev

# 1. Copy เฉพาะไฟล์ manifest เพื่อ cache dependencies
COPY Cargo.toml Cargo.lock ./

# 2. สร้าง dummy main.rs เพื่อ build dependencies
#    เทคนิคนี้ช่วยให้ Docker cache layer นี้ไว้ แม้เราจะแก้โค้ดใน src
RUN mkdir src && echo "fn main() {println!(\"caching deps...\");}" > src/main.rs
RUN cargo build --release

# 3. Copy source code จริง
COPY src ./src

# 4. Build application จริง (จะเร็วมากเพราะ dependencies ถูก cache ไว้แล้ว)
#    - RUN rm -f target/release/deps/your_app_name* # ลบ dummy file (your_app_name คือชื่อใน Cargo.toml)
RUN cargo build --release

# --- Stage 2: Final Image ---
# ใช้ base image ที่เล็กมากๆ เช่น alpine
FROM alpine:latest

WORKDIR /app

# สร้าง user ทั่วไปที่ไม่ใช่ root เพื่อความปลอดภัย
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy เฉพาะ binary ที่ compile เสร็จแล้วจาก stage 'builder'
# !!! 🛑 ข้อสำคัญ: เปลี่ยน 'your-app-name' เป็นชื่อ binary ของคุณ (ปกติคือชื่อ package ใน Cargo.toml)
COPY --from=builder /usr/src/app/target/release/your-app-name .

# ให้สิทธิ์ user 'appuser' เป็นเจ้าของ
RUN chown appuser:appgroup ./your-app-name

# เปลี่ยนไปรันด้วย user ธรรมดา
USER appuser

# คำสั่งที่จะรันเมื่อ container เริ่มทำงาน
CMD ["./your-app-name"]
