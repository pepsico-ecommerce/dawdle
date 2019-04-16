use Mix.Config

config :dawdle, Dawdle.Backend.SQS,
  region: "us-west-2",
  delay_queue: "hippware-dawdle-delay-test",
  message_queue: "hippware-dawdle-message-test.fifo"
