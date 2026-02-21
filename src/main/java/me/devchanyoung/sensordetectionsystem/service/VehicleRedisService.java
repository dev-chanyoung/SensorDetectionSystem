package me.devchanyoung.sensordetectionsystem.service;


import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class VehicleRedisService {

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    public void updateLatestStatus(String vehicleId, double speed, double rpm){
        String key = "vehicle:status:" + vehicleId;

        // 1. 저장 데이터 Map으로 구조화
        Map<String, Object> statusData = new HashMap<>();
        statusData.put("speed", speed);
        statusData.put("rpm", rpm);
        statusData.put("updatedAt", LocalDateTime.now().toString());

        try {
            // 2. Map 객체 JSON 문자열로 변환
            String jsonValue = objectMapper.writeValueAsString(statusData);

            // 3. Resid 저장
            redisTemplate.opsForValue().set(key, jsonValue);
        } catch (JsonProcessingException e) {
            log.error("Redis JSON 직렬화 실패. VehicleId: {}", vehicleId, e);
        }
    }

    public String getLatestStatus(String vehicleId) {
        String key = "vehicle:status:" + vehicleId;
        return redisTemplate.opsForValue().get(key);
    }
}
