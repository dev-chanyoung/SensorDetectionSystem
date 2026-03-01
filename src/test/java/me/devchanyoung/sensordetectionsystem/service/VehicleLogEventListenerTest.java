//package me.devchanyoung.sensordetectionsystem.service;
//
//import me.devchanyoung.sensordetectionsystem.domain.Alert;
//import me.devchanyoung.sensordetectionsystem.dto.VehicleLogSavedEvent;
//import me.devchanyoung.sensordetectionsystem.repository.AlertRepository;
//import org.junit.jupiter.api.BeforeEach;
//import org.junit.jupiter.api.DisplayName;
//import org.junit.jupiter.api.Test;
//import org.junit.jupiter.api.extension.ExtendWith;
//import org.mockito.InjectMocks;
//import org.mockito.Mock;
//import org.mockito.junit.jupiter.MockitoExtension;
//import org.springframework.test.util.ReflectionTestUtils;
//
//import static org.mockito.ArgumentMatchers.any;
//import static org.mockito.Mockito.times;
//import static org.mockito.Mockito.verify;
//
//@ExtendWith(MockitoExtension.class)
//public class VehicleLogEventListenerTest {
//
//    @InjectMocks
//    private VehicleLogEventListener eventListener;
//
//    @Mock
//    private AlertRepository alertRepository;
//
//    @Mock
//    private VehicleRedisService vehicleRedisService;
//
//    @BeforeEach
//    void setUp(){
//        ReflectionTestUtils.setField(eventListener, "speedLimit", 150.0);
//        ReflectionTestUtils.setField(eventListener,"rpmLimit", 5000.0);
//    }
//
//    @Test
//    @DisplayName("과속 및 급가속 임계치 초과 시 Alert이 각각 저장되고 Redis가 갱신")
//    void handleEvent_ExceedLimits_SavesAlerts() {
//        // Given 초과 데이터
//        VehicleLogSavedEvent event = new VehicleLogSavedEvent("Test-01", 160.0, 5500.0);
//
//        // When
//        eventListener.handleVehicleLogSavedEvent(event);
//
//        // Then
//        // Redis 갱신 로직 1회 호출
//        verify(vehicleRedisService, times(1)).updateLatestStatus("Test-01", 160.0, 5500.0);
//
//        // Alert 저장 2회(과속 1, 급가속 1) 호출
//        verify(alertRepository, times(2)).save(any(Alert.class));
//    }
//
//    @Test
//    @DisplayName("정상 수치일 경우 Alert은 저장되지 않고 Redis만 갱신")
//    void handleEvent_Normal_NoAlerts() {
//        // Given 정상 데이터
//        VehicleLogSavedEvent event = new VehicleLogSavedEvent("Test-02", 100.0, 3000.0);
//
//        // When
//        eventListener.handleVehicleLogSavedEvent(event);
//
//        // Then
//        // Redis 갱신 로직 1회 호출
//        verify(vehicleRedisService, times(1)).updateLatestStatus("Test-02", 100.0, 3000.0);
//
//        // Alert 저장 로직 0회 호출
//        verify(alertRepository, times(0)).save(any(Alert.class));
//    }
//}
