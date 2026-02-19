package me.devchanyoung.sensordetectionsystem.simulation;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import me.devchanyoung.sensordetectionsystem.service.VehicleLogService;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;


import java.util.Random;

@Slf4j
@Component
@RequiredArgsConstructor
public class SensorSimulator {

    private final VehicleLogService vehicleLogService;
    private final Random random = new Random();

    // 가상 차량 5대
    private static final String[] VEHICLE_IDS = {
            "Seoul-1", "Gyeonggi-1", "Busan-1", "Incheon-1", "Daegu-1"
    };

    @Scheduled(fixedRate = 1000)
    public void simulateSensorData(){
        // 1. 랜덤 차량 선택
        String vehicleId = VEHICLE_IDS[random.nextInt(VEHICLE_IDS.length)];

        // 2. 랜덤 데이터 형성
        double speed = 60 + random.nextDouble() * 110;
        double rpm = 1500 + random.nextDouble() * 4500;

        // 3. DTO 생성
        VehicleLogRequest request = new VehicleLogRequest();
        request.setVehicleId(vehicleId);
        request.setSpeed(Math.round(speed * 10.0) / 10.0);
        request.setRpm(Math.round(rpm * 10.0) / 10.0);

        // 4. 서비스 호출
        try {
            vehicleLogService.saveLog(request);
            log.info("[Simulation] Data Sent: {} | Speed: {} | RPM: {}", vehicleId, request.getSpeed(), request.getRpm());
        } catch (Exception e){
            log.error("Simulation Error: {}", e.getMessage());
        }
    }
}