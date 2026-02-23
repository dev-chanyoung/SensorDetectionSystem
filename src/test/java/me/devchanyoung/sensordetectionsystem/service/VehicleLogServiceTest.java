package me.devchanyoung.sensordetectionsystem.service;

import me.devchanyoung.sensordetectionsystem.domain.VehicleLog;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogRequest;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogSavedEvent;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogJdbcRepository;
import me.devchanyoung.sensordetectionsystem.repository.VehicleLogRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
public class VehicleLogServiceTest {

    @InjectMocks
    private VehicleLogService vehicleLogService;

    @Mock
    private VehicleLogRepository vehicleLogRepository;

    @Mock
    private VehicleLogJdbcRepository vehicleLogJdbcRepository;

    @Mock
    private ApplicationEventPublisher eventPublisher;

    @Test
    @DisplayName("정상 데이터 유입 시 DB 저장 및 비동기 이벤트 1회 발생")
    void saveLog_Success_PublishesEvent(){
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
        verify(eventPublisher, times(1)).publishEvent(any(VehicleLogSavedEvent.class));
    }


}
