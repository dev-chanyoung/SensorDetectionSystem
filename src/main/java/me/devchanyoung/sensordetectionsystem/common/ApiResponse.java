package me.devchanyoung.sensordetectionsystem.common;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class ApiResponse<T> {
    private String status;  // "SUCCESS" 또는 "ERROR"
    private String message; // 결과 메시지
    private T data;         // 실제 전달할 데이터 (제네릭)

    // 성공했을 때 쉽게 객체를 생성하기 위한 정적(Static) 팩토리 메서드
    public static <T> ApiResponse<T> success(String message, T data) {
        return new ApiResponse<>("SUCCESS", message, data);
    }
}