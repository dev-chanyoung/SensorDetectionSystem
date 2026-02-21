package me.devchanyoung.sensordetectionsystem.domain;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDate;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@Builder
public class DailyVehicleStats {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String vehicleId;

    private LocalDate recordDate;

    private double avgSpeed;
    private double maxSpeed;

    public static DailyVehicleStats createStats(String vehicleId, LocalDate recordDate, double avgSpeed, double maxSpeed) {
        return DailyVehicleStats.builder()
                .vehicleId(vehicleId)
                .recordDate(recordDate)
                .avgSpeed(avgSpeed)
                .maxSpeed(maxSpeed)
                .build();
    }
}