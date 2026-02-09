package me.devchanyoung.sensordetectionsystem.domain;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.*;

import java.time.LocalDateTime;


@Entity
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class VehicleLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String vehicleId;
    private double speed;
    private double rpm;
    private LocalDateTime createdat;

    public VehicleLog(String vehicleId, double speed, double rpm){
        this.vehicleId = vehicleId;
        this.speed = speed;
        this.rpm = rpm;
        this.createdat = LocalDateTime.now();
    }
}
