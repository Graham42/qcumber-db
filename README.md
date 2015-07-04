# Qcumber DB

This project holds scripts needed to recreate the database.

In the future may maintain a SQLite equivalent for development purposes.

## Dev Setup

1. Install and start docker
2. In root directory of the project (where the Dockerfile is) run `sudo docker build -t qc-db .`
   This will build a new image named `qc-db`.
3. Start a container with our new image by running

   ```
   sudo docker run -e POSTGRES_PASSWORD=sekret_pazwrd1$ -p 5432:5432 -d --name qcumberdb qc-db
   ```

    - You can check if the container is running with `sudo docker ps`.
    - Logs are also viewable with `sudo docker logs qcumberdb`
    - Because the container was started with the `-p` option to expose the port, the cli can be
      accessed with `psql -h localhost -U <user> <dbname>`
4. Data can be loaded by running the `load_dump_into_db.py`. It is recommended to set up a virtual
   env and install the needed requirements there with `pip install -r requirements.txt`.
