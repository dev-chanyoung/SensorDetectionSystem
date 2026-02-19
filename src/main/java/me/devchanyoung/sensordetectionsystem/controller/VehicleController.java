package me.devchanyoung.sensordetectionsystem.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import me.devchanyoung.sensordetectionsystem.common.ApiResponse;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogRequest;
import me.devchanyoung.sensordetectionsystem.service.VehicleLogService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
public class VehicleController {

    private final VehicleLogService vehicleLogService;

    // [변경] GET -> POST (데이터 생성은 POST가 표준)
    // [변경] @RequestParam -> @RequestBody (JSON으로 데이터를 받음)
    // @Valid 추가: DTO의 제약조건(@Min, @NotBlank 등)을 검사해라!
    @PostMapping("/api/log")
    public ResponseEntity<ApiResponse<Long>> saveLog(@Valid @RequestBody VehicleLogRequest request) {
        Long savedId = vehicleLogService.saveLog(request);

        // 통일된 규격(ApiResponse)으로 포장해서 반환
        ApiResponse<Long> response = ApiResponse.success("센서 데이터가 성공적으로 저장되었습니다.", savedId);
        return ResponseEntity.ok(response);
    }
}
