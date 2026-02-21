package me.devchanyoung.sensordetectionsystem.exception;


import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
@AllArgsConstructor
public enum ErrorCode {

    // 400 Bad Request
    INVALID_INPUT_VALUE(HttpStatus.BAD_REQUEST,"C001", "잘못된 입력값입니다."),
    INVALID_SENSOR_DATA(HttpStatus.BAD_REQUEST,"C002", "센서 데이터가 유효하지 않숩니다."),

    // 404 Not Found
    VEHICLE_NOT_FOUND(HttpStatus.NOT_FOUND,"V001","해당 차량 정보를 찾을 수 없습니다."),

    // 500 Internal Server Error
    INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "S001", "서버 내부 오류가 발생했습니다.");

    private final HttpStatus status;
    private final String code;
    private final String message;
}
