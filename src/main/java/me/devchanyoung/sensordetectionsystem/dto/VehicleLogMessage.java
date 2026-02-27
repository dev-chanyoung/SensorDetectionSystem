package me.devchanyoung.sensordetectionsystem.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
@AllArgsConstructor
public class VehicleLogMessage {
    private String vehicleId;
    private double speed;
    private double rpm;
}
