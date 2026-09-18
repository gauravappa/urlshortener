# --- Stage 1: Build the application ---
FROM eclipse-temurin:25-jdk-alpine AS builder

WORKDIR /build

# Copy the Maven/Gradle wrapper and configuration files first (for layer caching)
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Give execution permission to the maven wrapper
RUN chmod +x ./mvnw

# Download dependencies (this layer will be cached unless pom.xml changes)
RUN ./mvnw dependency:go-offline

# Copy the actual source code and build the application
COPY src src
RUN ./mvnw clean package -DskipTests

# --- Stage 2: Create the minimal runtime image ---
FROM eclipse-temurin:25-jre-alpine

WORKDIR /app

# Copy ONLY the built JAR from the builder stage
COPY --from=builder /build/target/*.jar app.jar

# Expose port 8080
EXPOSE 8080

# Start the application
ENTRYPOINT ["java", "-jar", "app.jar"]