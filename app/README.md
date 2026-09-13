# Application

Made a very small Python HTTP application just to have something to deploy on Kubernetes.

First I tested the app directly on my Mac:

![Local app test](./architecture/local-app-test.jpeg)

Then I created a Dockerfile, built the image and ran the same app inside a Docker container.

The response from inside the container:

![App running inside container](./architecture/local-app.jpeg)

After testing it locally, I pushed the image to Docker Hub:

`pranjalbisen/seedhe-k8s-app:1.0`

I also created `deployment.yml` which will be used in Kubernetes to run 3 replicas of this application.

