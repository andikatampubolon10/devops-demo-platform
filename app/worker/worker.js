const amqp = require("amqplib");

const RABBITMQ_URL = process.env.RABBITMQ_URL || "amqp://rabbitmq:5672";
const QUEUE_NAME = "orders";

async function startWorker() {
    console.log("Connecting to RabbitMQ...");

    const connection = await amqp.connect(RABBITMQ_URL);
    const channel = await connection.createChannel();

    await channel.assertQueue(QUEUE_NAME, {
        durable: true
    });

    channel.prefetch(1);

    console.log("Worker is waiting for orders...");

    channel.consume(QUEUE_NAME, async (message) => {
        if (message !== null) {
            const order = JSON.parse(message.content.toString());

            console.log("=================================");
            console.log("New order received!");
            console.log("Order ID:", order.id);
            console.log("Product:", order.product);
            console.log("Quantity:", order.quantity);
            console.log("=================================");

            await new Promise(resolve => setTimeout(resolve, 2000));

            console.log(`Order ${order.id} processed successfully`);

            channel.ack(message);
        }
    });
}

startWorker().catch((error) => {
    console.error("Worker failed:", error);
    process.exit(1);
});
