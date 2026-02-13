package me.devchanyoung.sensordetectionsystem.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogRequest;
import me.devchanyoung.sensordetectionsystem.service.VehicleLogService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
public class VehicleController {

    private final VehicleLogService vehicleLogService;

    // [변경] GET -> POST (데이터 생성은 POST가 표준)
    // [변경] @RequestParam -> @RequestBody (JSON으로 데이터를 받음)
    // @Valid 추가: DTO의 제약조건(@Min, @NotBlank 등)을 검사해라!
    @PostMapping("/api/log")
    public String saveLog(@Valid @RequestBody VehicleLogRequest request) {
        Long savedId = vehicleLogService.saveLog(request);
        return "저장 성공! ID: " + savedId;
    }
}
