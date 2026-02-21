package me.devchanyoung.sensordetectionsystem.service;

import lombok.RequiredArgsConstructor;
import me.devchanyoung.sensordetectionsystem.domain.Alert;
import me.devchanyoung.sensordetectionsystem.domain.AlertType;
import me.devchanyoung.sensordetectionsystem.domain.VehicleLog;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogRequest;
import me.devchanyoung.sensordetectionsystem.repository.AlertRepository;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogJdbcRepository;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class VehicleLogService {

    private final VehicleLogRepository vehicleLogRepository;
    private final AlertRepository alertRepository;
    private final VehicleLogJdbcRepository vehicleLogJdbcRepository;
    private final VehicleRedisService vehicleRedisService;

    @Value("${sensor.limit.speed}")
    private double speedLimit;

    @Value("${sensor.limit.rpm}")
    private double rpmLimit;

    // 트랜잭션: 이 메서드 안의 작업은 모두 성공하거나, 하나라도 실패하면 모두 취소됨
    @Transactional
    public Long saveLog(VehicleLogRequest request) {
        // 1. DTO를 Entity로 변환
        VehicleLog vehicleLog = request.toEntity();

        // 2. Repository에 저장 요청
        VehicleLog savedLog = vehicleLogRepository.save(vehicleLog);

        // 3. 이상 탐지 로직 실행 + 나중에 로그 저장과 분리하여 병목 현상 예방 -> 별도 쓰레드 or 메세지 큐(Kafka) 이용
        checkAnomaly(request);

        // 4. Redis 상태 갱신
        vehicleRedisService.updateLatestStatus(request.getVehicleId(), request.getSpeed(), request.getRpm());

        // 5. 저장된 ID 반환
        return savedLog.getId();
    }

    public void checkAnomaly(VehicleLogRequest request) {
        // 과속 체크 (150km/h 초과)
        if (request.getSpeed() > speedLimit) {
            saveAlert(request.getVehicleId(), AlertType.SPEEDING, request.getSpeed());
        }

        // 급가속 체크(5000rpm 초과)
        if (request.getRpm() > rpmLimit) {
            saveAlert(request.getVehicleId(), AlertType.SUDDEN_ACCEL, request.getRpm());
        }
    }

    private void saveAlert(String vehicleId, AlertType type, double checkedValue) {
        Alert alert = Alert.createAlert(vehicleId, type, checkedValue);
        alertRepository.save(alert);
    }

    @Transactional
    public void saveBulkLogs(List<VehicleLogRequest> requests) {
        // 1. DTO 리스트 -> Entity 리스트
        List<VehicleLog> logs = requests.stream()
                .map(VehicleLogRequest::toEntity)
                .toList();

        // 2. JdbcTemplate을 이용해 한 번에 저장 (속도 극대화)
        vehicleLogJdbcRepository.saveAllBulk(logs);

        // 3. 이상 징후 탐지
        for(VehicleLogRequest request : requests){
            checkAnomaly(request);
            vehicleRedisService.updateLatestStatus(request.getVehicleId(),request.getSpeed(), request.getRpm());
            // 지금은 루프로 하지만  Alter 저장도 Bulk or Kafka로 변경 예정
        }
    }







}