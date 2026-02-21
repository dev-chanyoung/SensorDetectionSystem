package me.devchanyoung.sensordetectionsystem.domain;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@Builder
public class HourlyVehicleStats {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String vehicleId;

    private LocalDateTime recordHour;

    private double avgSpeed;
    private double maxSpeed;
    private long dataCount;

    public static HourlyVehicleStats create(String vehicleId, LocalDateTime recordHour, Double avgSpeed, Double maxSpeed, long dataCount){
        return HourlyVehicleStats.builder()
                .vehicleId(vehicleId)
                .recordHour(recordHour)
                .avgSpeed(avgSpeed)
                .maxSpeed(maxSpeed)
                .dataCount(dataCount)
                .build();
    }
}
