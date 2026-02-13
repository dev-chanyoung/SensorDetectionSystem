package me.devchanyoung.sensordetectionsystem.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class ErrorResponse {
    private String code;    // 예: "400 Bad Request"
    private String message; // 예: "속도는 0 이상이어야 합니다."
}