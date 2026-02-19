package me.devchanyoung.sensordetectionsystem.exception;

import me.devchanyoung.sensordetectionsystem.dto.ErrorResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice // 프로젝트 전역에서 발생하는 예외를 낚아채는 역할
public class GlobalExceptionHandler {

    // @Valid 검증 실패 시 발생하는 예외(MethodArgumentNotValidException)를 처리
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationException(MethodArgumentNotValidException e) {
        // 에러 메시지 중 첫 번째 것만 가져옴
        BindingResult bindingResult = e.getBindingResult();
        String firstErrorMessage = bindingResult.getFieldError().getDefaultMessage();

        // 포맷으로 변환
        ErrorResponse response = new ErrorResponse("INVALID_INPUT", firstErrorMessage);

        // HTTP 상태 코드 400(Bad Request)와 함께 반환
        return ResponseEntity.badRequest().body(response);
    }


}