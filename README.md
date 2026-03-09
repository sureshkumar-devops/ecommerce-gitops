vi git-creds.yaml
------------------
apiVersion: v1
kind: Secret
metadata:
  name: git-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  url: "gitops repo url"
  username: git username
  password: ghp_pat

---------------------
vi dockerhub-creds.yaml
--------------------------
apiVersion: v1
kind: Secret
metadata:
  name: dockerhub-creds
  namespace: argocd
  labels:
    argocd-image-updater.argoproj.io/secret-type: pullsecret
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
       "auths": {
          "https://registry-1.docker.io": {
             "username": "docker username",
             "password": "dckr_pat_token",
             "auth": 'username:password' | base64'
             }
        }
    }
Generate the correct base64 string
Run this on your machine (replace with your actual PAT):
echo -n 'username:password' | base64 -w0
