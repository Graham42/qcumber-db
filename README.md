# Qcumber DB

This project holds scripts needed to recreate the database.

In the future may maintain a SQLite equivalent for development purposes.

## Dev Setup

1. Install and start docker
2. In root directory of the project (where the Dockerfile is) run `sudo docker build -t qc-db .`
   This will build a new image named `qc-db`.
3. Start a contiamer with our new image by running
   `sudo docker run -e POSTGRES_PASSWORD=sekret_pazwrd1$ -p 5432:5432 -d qc-db`
    - You can check if the container is running with `sudo docker ps`. Docker will have given the
      container some quirky name like `distracted_torvalds`
    - Logs are also viewable with `sudo docker logs distracted_torvalds`
