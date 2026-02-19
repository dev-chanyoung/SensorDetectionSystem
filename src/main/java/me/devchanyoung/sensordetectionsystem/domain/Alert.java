package me.devchanyoung.sensordetectionsystem.domain;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor(access = AccessLevel.PRIVATE)
@Builder
public class Alert {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String vehicleId;

    @Enumerated(EnumType.STRING)
    private AlertType alertType;

    @Column(name = "checked_value")
    private double checkedValue;

    private LocalDateTime createdAt;

    public static Alert createAlert(String vehicleId, AlertType type, double checkedValue) {
        return Alert.builder()
                .vehicleId(vehicleId)
                .alertType(type)
                .checkedValue(checkedValue)
                .createdAt(LocalDateTime.now())
                .build();
    }
}
