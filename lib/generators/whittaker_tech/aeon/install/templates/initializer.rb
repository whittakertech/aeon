# frozen_string_literal: true

WhittakerTech::Aeon.configure do |config|
  # How far ahead of Time.current the projector extends by default.
  # config.projection_buffer = 14.days

  # Absolute ceiling on how far a single allocation can be projected.
  # config.max_projection_window = 1.year

  # Retention strategy for invalidated occurrences
  # (:ephemeral, :windowed, :historical, or :permanent).
  # config.disposal_policy = :windowed

  # How long invalidated occurrences are retained before the Disposer purges them.
  # config.invalidated_retention_window = 60.days

  # ActiveJob queue backend for ProjectionJob (:sidekiq, :async, etc.).
  # config.queue_adapter = :sidekiq
end
