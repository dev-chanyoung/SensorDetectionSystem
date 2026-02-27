package me.devchanyoung.sensordetectionsystem.service;

import lombok.RequiredArgsConstructor;
import me.devchanyoung.sensordetectionsystem.config.RabbitMQConfig;
import me.devchanyoung.sensordetectionsystem.domain.Alert;
import me.devchanyoung.sensordetectionsystem.domain.AlertType;
import me.devchanyoung.sensordetectionsystem.domain.VehicleLog;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogMessage;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogRequest;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogSavedEvent;
import me.devchanyoung.sensordetectionsystem.repository.AlertRepository;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogJdbcRepository;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogRepository;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
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
    private final RabbitTemplate rabbitTemplate;



    @Transactional
    public Long saveLog(VehicleLogRequest request) {
        // 1. 센서 데이터 DB 저장
        VehicleLog logEncitiy = VehicleLog.builder()
                .vehicleId(request.getVehicleId())
                .speed(request.getSpeed())
                .rpm(request.getRpm())
                .build();
        VehicleLog savedLog = vehicleLogRepository.save(logEncitiy);

        // 2. RabbitMQ로 메시지 발행(비동기 처리 외부 큐로 위임)
        VehicleLogMessage message = new VehicleLogMessage(
                savedLog.getVehicleId(),
                savedLog.getSpeed(),
                savedLog.getRpm()
        );

        rabbitTemplate.convertAndSend(
                RabbitMQConfig.EXCHANGE_NAME,
                RabbitMQConfig.ROUTING_KEY,
                message
        );

        return savedLog.getId();
    }

    @Transactional
    public void saveBulkLogs(List<VehicleLogRequest> requests) {
        // 1. Request DTO List -> Entity List 변환
        List<VehicleLog> logs = requests.stream()
                .map(req -> VehicleLog.builder()
                        .vehicleId(req.getVehicleId())
                        .speed(req.getSpeed())
                        .rpm(req.getRpm())
                        .build())
                .toList();

        vehicleLogJdbcRepository.saveAllBulk(logs);

        // 3. 저장된 데이터를 순회하며 RabbitMQ 큐에 비동기 메시지 발행
        for (VehicleLogRequest request : requests) {
            VehicleLogMessage message = new VehicleLogMessage(
                    request.getVehicleId(),
                    request.getSpeed(),
                    request.getRpm()
            );

            rabbitTemplate.convertAndSend(
                    RabbitMQConfig.EXCHANGE_NAME,
                    RabbitMQConfig.ROUTING_KEY,
                    message
            );
        }
    }
}