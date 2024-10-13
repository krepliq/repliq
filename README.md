# k8s-repli-queue

**k8s-repli-queue** is a copyleft, open-source, Kubernetes-native message queue written in Rust for deterministic,
low-latency inter-process communication (IPC) and cross-machine replication.

Inspired by [Chronicle Queue](https://chronicle.software/queue/).

![repliq](./images/readme/repliq_640_320.png)

## Key Features

- **Asynchronous replication:** Enables scalable, cross-machine communication with low latency.
- **Memory-mapped files:** Provides ultra-fast data access and efficient sharing between processes.
- **Familiar Queue interface:** Offers an intuitive API for easy integration.
- **Kubernetes-native:** Leverages Kubernetes features for seamless deployment and management.

## Coming Soon

**Target Release: 2025 Q1**

Stay tuned for updates and the initial release.

## Preview of the API (Subject to Change)

```rust
use async_trait::async_trait;
use std::io;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum QueueError {
    #[error("I/O error: {0}")]
    Io(#[from] io::Error),

    #[error("Replication error: {0}")]
    Replication(String),

    #[error("Queue is full")]
    Full,

    #[error("Queue is empty")]
    Empty,

    #[error("Invalid configuration: {0}")]
    InvalidConfig(String),

    #[error("Serialization error: {0}")]
    Serialization(String),

    #[error("Deserialization error: {0}")]
    Deserialization(String),

    #[error("Unexpected error: {0}")]
    Other(String),
}

pub enum ReplicationMode {
    Synchronous,
    Asynchronous,
}

#[async_trait]
pub trait Queue<T: Send + Sync> {
    async fn enqueue(&self, item: T) -> Result<(), QueueError>;
    async fn dequeue(&self) -> Result<Option<T>, QueueError>;
}

#[async_trait]
pub trait PersistentQueue<T: Send + Sync>: Queue<T> {
    fn new(path: &str, capacity: usize) -> Result<Self, QueueError>
    where
        Self: Sized;

    fn open(path: &str) -> Result<Self, QueueError>
    where
        Self: Sized;
}

#[async_trait]
pub trait ReplicatedQueue<T: Send + Sync>: PersistentQueue<T> {
    fn configure_replication(
        &mut self,
        primary_node: &str,
        secondary_nodes: Vec<&str>,
        replication_mode: ReplicationMode,
    ) -> Result<(), QueueError>;
}

pub struct ReplicatedQueueImpl<T: Send + Sync>(std::marker::PhantomData<T>);

#[async_trait]
impl<T: Send + Sync> Queue<T> for ReplicatedQueueImpl<T> {
    async fn enqueue(&self, item: T) -> Result<(), QueueError> {
        // Implementation details...
        Ok(())
    }

    async fn dequeue(&self) -> Result<Option<T>, QueueError> {
        // Implementation details...
        Ok(None)
    }
}

impl<T: Send + Sync> PersistentQueue<T> for ReplicatedQueueImpl<T> {
    fn new(path: &str, capacity: usize) -> Result<Self, QueueError> {
        // Implementation details...
        Ok(ReplicatedQueueImpl(std::marker::PhantomData))
    }

    fn open(path: &str) -> Result<Self, QueueError> {
        // Implementation details...
        Ok(ReplicatedQueueImpl(std::marker::PhantomData))
    }
}

impl<T: Send + Sync> ReplicatedQueue<T> for ReplicatedQueueImpl<T> {
    fn configure_replication(
        &mut self,
        primary_node: &str,
        secondary_nodes: Vec<&str>,
        replication_mode: ReplicationMode,
    ) -> Result<(), QueueError> {
        // Implementation details...
        Ok(())
    }
}
```

## Sample Usage

```rust
use repliq::{ReplicatedQueue, ReplicationMode};
use std::process::{Command, Stdio};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // In the parent process, create a new replicated queue
    let mut parent_queue: impl ReplicatedQueue<String> = ReplicatedQueueImpl::new(
        "my_queue",
        1024,
        "localhost:31337", // Use localhost for this example
        vec![],            // No secondary nodes in this simple example
        ReplicationMode::Asynchronous,
    )?;

    // Enqueue an item in the parent process
    parent_queue.enqueue("Hello from parent!".to_string()).await?;

    // In the child process (simulated here), connect to the existing queue by name
    let mut child_queue: impl ReplicatedQueue<String> = ReplicatedQueue::open("my_queue")?;

    // Dequeue the item in the child process
    let item = child_queue.dequeue().await?;
    if let Some(message) = item {
        // Send the dequeued message back to the parent process via stdout
        if let Some(mut stdin) = child.stdin.take() {
            stdin.write_all(format!("{}\n", message).as_bytes()).await?;
        }
    }

    // Read the message from the child process's stdout in the parent process
    if let Some(stdout) = child.stdout.take() {
        let mut reader = BufReader::new(stdout).lines();
        while let Some(line) = reader.next_line().await? {
            println!("Child process received: {}", line);
        }
    }

    Ok(())
}
```

## Kubernetes Usage (Proposed)

**k8s-repli-queue** is designed to be Kubernetes-native. You'll be able to deploy it as a Docker container within your
Kubernetes cluster and configure it using Kubernetes resources like ConfigMaps and Secrets.

**Example Deployment (Conceptual):**

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: repliq-daemon
spec:
  selector:
    matchLabels:
      name: repliq
  template:
    metadata:
      labels:
        name: repliq
    spec:
      containers:
        - name: repliq
          image: mahurangisoftware/k8s-repli-queue:latest
          resources:
            limits:
              memory: 200Mi
            requests:
              cpu: 100m
              memory: 200Mi
          volumeMounts:
            - name: repliq-storage
              mountPath: /var/lib/repliq
          ports:
            - containerPort: 31337
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: REPLIQ_CONFIG
              valueFrom:
                configMapKeyRef:
                  name: repliq-config
                  key: config.yaml
      volumes:
        - name: repliq-storage
          hostPath:
            path: /var/lib/repliq
            type: DirectoryOrCreate

---

apiVersion: v1
kind: ConfigMap
metadata:
  name: repliq-config
data:
  config.yaml: |
    replication:
      mode: async
      discovery:
        method: kubernetes
        label_selector: name=repliq
    queue:
      capacity: 1000000
      persistence:
        path: /var/lib/repliq/data

---

apiVersion: v1
kind: Service
metadata:
  name: repliq-service
spec:
  selector:
    name: repliq
  ports:
    - protocol: TCP
      port: 31337
      targetPort: 31337
  type: ClusterIP
```

## Grafana Dashboard

![repliq Dashboard](images/readme/repliq_dashboard.png)

## Integrations

**k8s-repli-queue** seamlessly integrates with various tools and platforms to enhance monitoring, scaling, and overall
operational efficiency:

- **Prometheus**: Export key metrics for comprehensive monitoring and alerting.
- **Grafana/Telegraf**: Visualize repliq performance data with customizable dashboards.
- **Redis Streams**: Leverage Redis' speed and simplicity for real-time data ingestion and processing.
- **NATS**: Integrate with NATS for a high-performance, cloud-native messaging solution.
- **RabbitMQ**: Connect repliq with RabbitMQ for robust message queuing and delivery guarantees.
- **InfluxDB**: Store and analyze time-series metrics data from repliq for performance monitoring and capacity planning.
- **Fluentd/FluentBit**: Collect and forward repliq logs to central logging systems (e.g., Elasticsearch, Splunk) for
  analysis and monitoring.
- **Jaeger**: Visualize message flow and trace message journeys through repliq queues and across replicas.
- **Kafka**: Seamlessly connect repliq with Kafka to leverage its distributed streaming capabilities.
- **Slack**: Share high-frequency tick data with your colleagues.

For detailed integration guides and examples, please refer to our [documentation](https://docs.repliq.io/integrations).

## Benchmarks

![repliq Benchmarks](images/readme/repliq_off_the_charts.png)

## License

This project is licensed under the [GNU General Public License](LICENSE).

---
