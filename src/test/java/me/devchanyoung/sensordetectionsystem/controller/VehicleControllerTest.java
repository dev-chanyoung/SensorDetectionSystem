package me.devchanyoung.sensordetectionsystem.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import me.devchanyoung.sensordetectionsystem.dto.VehicleLogRequest;
import me.devchanyoung.sensordetectionsystem.exception.ErrorCode;
import me.devchanyoung.sensordetectionsystem.service.VehicleLogService;
import me.devchanyoung.sensordetectionsystem.service.VehicleRedisService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = VehicleController.class)
class VehicleControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private VehicleLogService vehicleLogService;

    @MockBean
    private VehicleRedisService vehicleRedisService;

    @Test
    @DisplayName("유효하지 않은 센서 데이터(음수 속도) 요청 시 400 에러와 커스텀 에러 코드를 반환한다.")
    void saveLog_InvalidData_Returns400AndErrorCode() throws Exception {
        // Given (유효성 검사를 실패할 비정상 데이터 세팅: 속도 -10.0)
        VehicleLogRequest invalidRequest = new VehicleLogRequest();
        invalidRequest.setVehicleId("Test-03");
        invalidRequest.setSpeed(-10.0);
        invalidRequest.setRpm(3000.0);

        String requestJson = objectMapper.writeValueAsString(invalidRequest);

        // When & Then
        mockMvc.perform(post("/api/log")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(requestJson))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(ErrorCode.INVALID_INPUT_VALUE.getCode()))
                .andExpect(jsonPath("$.message").exists());
    }
}