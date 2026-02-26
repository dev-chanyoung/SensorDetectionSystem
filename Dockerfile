# 1. 실행 환경: Java 17 경량화 이미지 사용
FROM eclipse-temurin:17-jdk-alpine

# 2. 컨테이너 내부의 작업 디렉토리 설정
WORKDIR /app

# 3. 빌드된 JAR 파일의 경로를 변수로 설정
ARG JAR_FILE=build/libs/*.jar

# 4. JAR 파일을 컨테이너 내부로 복사
COPY ${JAR_FILE} app.jar

# 5. 컨테이너가 실행될 때 수행할 명령어 (스프링 부트 실행)
ENTRYPOINT ["java", "-jar", "app.jar"]