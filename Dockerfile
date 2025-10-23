# Multi-stage build para Eureka Service Discovery

# Stage 1: Build
FROM maven:3.9-eclipse-temurin-17-alpine AS build
WORKDIR /app

# Copiar archivos de configuración de Maven
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .

# Descargar dependencias (esta capa se cachea si pom.xml no cambia)
RUN mvn dependency:go-offline -B

# Copiar código fuente
COPY src ./src

# Compilar la aplicación (sin ejecutar tests para acelerar el build)
RUN mvn clean package -DskipTests

# Stage 2: Runtime
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Crear usuario no-root para seguridad
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Copiar el JAR compilado desde el stage de build
COPY --from=build /app/target/*.jar app.jar

# Cambiar permisos
RUN chown -R appuser:appgroup /app

# Cambiar a usuario no-root
USER appuser

# Exponer puerto (Railway usa la variable PORT automáticamente)
EXPOSE ${EUREKA_PORT:-8761}

# Variables de entorno por defecto
ENV JAVA_OPTS="-Xmx512m -Xms256m"

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${EUREKA_PORT:-8761}/actuator/health || exit 1

# Comando de inicio
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
