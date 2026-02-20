package me.devchanyoung.sensordetectionsystem.service;


import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class VehicleRedisService {

    private final StringRedisTemplate redisTemplate;

    public void updateLatestStatus(String vehicleId, double speed, double rpm){
        String key = "vehicle:status:" + vehicleId;
        String value = String.format("Speed: %.1f, RPM: %.1f, UpdatedAt: %s", speed, rpm, LocalDateTime.now());

        redisTemplate.opsForValue().set(key, value);
    }

    public String getLatestStatus(String vehicleId) {
        String key = "vehicle:status:" + vehicleId;
        return redisTemplate.opsForValue().get(key);
    }
}
