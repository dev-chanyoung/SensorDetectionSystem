package me.devchanyoung.sensordetectionsystem.service;

import me.devchanyoung.sensordetectionsystem.config.RabbitMQConfig;
import me.devchanyoung.sensordetectionsystem.domain.VehicleLog;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogRequest;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogJdbcRepository;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.amqp.rabbit.core.RabbitTemplate;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.ArgumentMatchers.eq;

@ExtendWith(MockitoExtension.class)
public class VehicleLogServiceTest {

    @InjectMocks
    private VehicleLogService vehicleLogService;

    @Mock
    private VehicleLogRepository vehicleLogRepository;

    @Mock
    private VehicleLogJdbcRepository vehicleLogJdbcRepository;

    @Mock
    private RabbitTemplate rabbitTemplate;

    @Test
    @DisplayName("정상 데이터 유입 시 DB 저장 및 RabbitMQ 메시지 1회 발생")
    void saveLog_Success_PublishesMessage(){
        // Given
        VehicleLogRequest request = new VehicleLogRequest();
        request.setVehicleId("Test-01");
        request.setSpeed(100.0);
        request.setRpm(3000.0);

        VehicleLog mockSavedLog = VehicleLog.builder()
                .id(1L)
                .vehicleId("Test-01")
                .speed(100.0)
                .rpm(3000.0)
                .build();

        given(vehicleLogRepository.save(any(VehicleLog.class))).willReturn(mockSavedLog);

        // When
        Long savedId = vehicleLogService.saveLog(request);

        // Then
        assertThat(savedId).isEqualTo(1L);
        verify(vehicleLogRepository, times(1)).save(any(VehicleLog.class));

        verify(rabbitTemplate, times(1)).convertAndSend(
                eq(RabbitMQConfig.EXCHANGE_NAME),
                eq(RabbitMQConfig.ROUTING_KEY),
                any(List.class)
        );
    }


}
