package me.devchanyoung.sensordetectionsystem.service;


import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import me.devchanyoung.sensordetectionsystem.domain.Alert;
import me.devchanyoung.sensordetectionsystem.domain.AlertType;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogSavedEvent;
import me.devchanyoung.sensordetectionsystem.repository.AlertRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Slf4j
@Component
@RequiredArgsConstructor
public class VehicleLogEventListener {

    private final AlertRepository alterRepository;
    private final VehicleRedisService vehicleRedisService;
    private final AlertRepository alertRepository;

    @Value("${sensor.limit.speed}")
    private double speedLimit;

    @Value("${sensor.limit.rpm}")
    private double rpmLimit;

    @Async
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleVehicleLogSavedEvent(VehicleLogSavedEvent event){
        try {
            // 1, Redis 최신 상태 갱신
            vehicleRedisService.updateLatestStatus(event.vehicleId(), event.speed(), event.rpm());

            // 2. 이상 징후 탐지 및 Alert 저장
            if (event.speed() > speedLimit) {
                saveAlert(event.vehicleId(), AlertType.SPEEDING, event.speed());
            }
            if (event.rpm() > rpmLimit) {
                saveAlert(event.vehicleId(), AlertType.SUDDEN_ACCEL, event.rpm());
            }
        } catch (Exception e) {
            log.error("부가 로직(Alert/Redis) 처리 중 오류 발생. VehicleId: {}", event.vehicleId(), e);
        }
    }

    private void saveAlert(String vehicleId, AlertType type, double checkedValue) {
        Alert alert = Alert.createAlert(vehicleId, type, checkedValue);
        alertRepository.save(alert);
        log.warn("[경고] 이상 탐지 - 차량: {}, 타입: {}, 수치: {}", vehicleId, type, checkedValue);
    }
}
