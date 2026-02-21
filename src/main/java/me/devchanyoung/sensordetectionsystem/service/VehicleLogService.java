package me.devchanyoung.sensordetectionsystem.service;

import lombok.RequiredArgsConstructor;
import me.devchanyoung.sensordetectionsystem.domain.Alert;
import me.devchanyoung.sensordetectionsystem.domain.AlertType;
import me.devchanyoung.sensordetectionsystem.domain.VehicleLog;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogRequest;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogSavedEvent;
import me.devchanyoung.sensordetectionsystem.repository.AlertRepository;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogJdbcRepository;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class VehicleLogService {

    private final VehicleLogRepository vehicleLogRepository;
    private final VehicleLogJdbcRepository vehicleLogJdbcRepository;

    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public Long saveLog(VehicleLogRequest request) {
        // 1. DTO를 Entity로 변환
        VehicleLog vehicleLog = request.toEntity();

        // 2. Repository에 저장 요청
        VehicleLog savedLog = vehicleLogRepository.save(vehicleLog);

        // 3. 이벤트 발행
        eventPublisher.publishEvent(new VehicleLogSavedEvent(request.getVehicleId(), request.getSpeed(), request.getRpm()));

        return savedLog.getId();
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
            eventPublisher.publishEvent(new VehicleLogSavedEvent(request.getVehicleId(), request.getSpeed(), request.getRpm()));
        }
    }
}