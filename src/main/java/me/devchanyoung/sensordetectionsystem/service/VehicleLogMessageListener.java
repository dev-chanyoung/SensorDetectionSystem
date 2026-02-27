package me.devchanyoung.sensordetectionsystem.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import me.devchanyoung.sensordetectionsystem.config.RabbitMQConfig;
import me.devchanyoung.sensordetectionsystem.domain.Alert;
import me.devchanyoung.sensordetectionsystem.domain.AlertType;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogMessage;
import me.devchanyoung.sensordetectionsystem.repository.AlertRepository;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.actuate.endpoint.web.servlet.AdditionalHealthEndpointPathsWebMvcHandlerMapping;
import org.springframework.stereotype.Component;

import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class VehicleLogMessageListener {

    private final AlertRepository alertRepository;
    private final VehicleRedisService vehicleRedisService;

    @Value("${vehicle.limit.speed: 150}")
    private double speedLimit;

    @Value("${vehicle.limit.rpm: 5000}")
    private double rpmLimit;

    @RabbitListener(queues = RabbitMQConfig.ALERT_QUEUE_NAME)
    public void receiveMessage(List<VehicleLogMessage> messages) {
        for (VehicleLogMessage message : messages) {
            try {
                // 1. Redis 최신 상태 갱신
                vehicleRedisService.updateLatestStatus(message.getVehicleId(), message.getSpeed(), message.getRpm());

                // 이상 탐지 로지(Alert)
                if (message.getSpeed() > speedLimit) {
                    alertRepository.save(Alert.createAlert(message.getVehicleId(), AlertType.SPEEDING, message.getSpeed()));
                }

                if (message.getRpm() > rpmLimit) {
                    alertRepository.save(Alert.createAlert(message.getVehicleId(), AlertType.SUDDEN_ACCEL, message.getRpm()));
                }
            } catch (Exception e) {
                log.error("MQ 메시지 처리 실패 - 차량: {}", message.getVehicleId(), e);
                throw e;
            }
        }
    }
}
