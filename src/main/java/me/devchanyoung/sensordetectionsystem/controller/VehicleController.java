package me.devchanyoung.sensordetectionsystem.controller;

import lombok.RequiredArgsConstructor;
import me.devchanyoung.sensordetectionsystem.domain.VehicleLog;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
public class VehicleController {

    private final VehicleLogRepository vehicleLogRepository;

    // 테스트용
    @GetMapping("/api/log")
    public String savedLog(@RequestParam String carId,
                           @RequestParam double speed,
                           @RequestParam double rpm) {

        VehicleLog log = VehicleLog.builder()
                .vehicleId(carId)
                .speed(speed)
                .rpm(rpm)
                .build();

        vehicleLogRepository.save(log);

        return "저장 성공x! ID: " + log.getId();
    }
}
