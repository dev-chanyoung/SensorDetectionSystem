package me.devchanyoung.sensordetectionsystem.repository;

import me.devchanyoung.sensordetectionsystem.domain.Alert;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AlertRepository extends JpaRepository<Alert, Long> {
}
