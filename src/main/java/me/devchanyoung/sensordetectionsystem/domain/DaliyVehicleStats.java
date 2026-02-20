package me.devchanyoung.sensordetectionsystem.domain;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.*;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@Builder
public class DaliyVehicleStats {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String vehicleId;
    private LocalDate recordDate;
    private double avgSpeed;
    private double maxSpeed;


    public static DaliyVehicleStats createStats(String vehicleId, LocalDate recordDate, Double avgSpeed, Double maxSpeed){
        return DaliyVehicleStats.builder()
                .vehicleId(vehicleId)
                .recordDate(recordDate)
                .avgSpeed(avgSpeed)
                .maxSpeed(maxSpeed)
                .build();
    }
}
