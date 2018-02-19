State, due to a bug Kubernetes lost the state of a persistent volume. The volume existed in AWS, so I've decided to recover the state.


PVC existed but with state Lost:

```
kubectl -n acdc-legacy get pvc
NAME                                            STATUS    VOLUME                                     CAPACITY   ACCESSMODES   STORAGECLASS   AGE
acdclegacy-staging-data-acdclegacy-postgres-0   Lost      pvc-dbd2ac08-f32e-11e7-b70d-1212ccc85de2   0                        default        10d
```

PV `pvc-dbd2ac08-f32e-11e7-b70d-1212ccc85de2` was inexistent.

Since the PV was created with K8S AWS dynamic Storageclass I couldn't simply recreate it.


First step, record the name of the PV that our PVC that is in Lost state:

In my case: `pvc-dbd2ac08-f32e-11e7-b70d-1212ccc85de2`

Download the spec of current pvc:

```
kubectl get pvc/acdclegacy-staging-data-acdclegacy-postgres-0 -o yaml > pvc.yml
```

Delete the current pvc (relax we'll create it again later):

```
kubectl delete pvc/acdclegacy-staging-data-acdclegacy-postgres-0
```

Download a manifest of another PV created by AWS dynamic storageclass:

```
kubectl get pv/another-pv -o yaml > dynamic-pv.yml
```

Here's what we need to do, remove the PVC spec, we'll recreate the PVC later. Change the fields with comments:

```yml
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    kubernetes.io/createdby: aws-ebs-dynamic-provisioner
    pv.kubernetes.io/bound-by-controller: "yes"
    pv.kubernetes.io/provisioned-by: kubernetes.io/aws-ebs
  labels:
    failure-domain.beta.kubernetes.io/region: us-east-1
    failure-domain.beta.kubernetes.io/zone: us-east-1a
  name: pvc-dbd2ac08-f32e-11e7-b70d-1212ccc85de2 # Here, change the name to the old lost pv
spec:
  accessModes:
  - ReadWriteOnce
  awsElasticBlockStore:
    fsType: ext4
    volumeID: aws://us-east-1a/vol-0e839e7704e937323 # Go to AWS find the disk id of our lost PV
  capacity:
    storage: 10Gi # Make sure the number of gigs matches our volume in aws
  # claimRef: # comment this lines
  #   apiVersion: v1
  #   kind: PersistentVolumeClaim
  #   name: acdclegacy-staging-data-acdclegacy-postgres-0
  #   namespace: acdc-legacy
  persistentVolumeReclaimPolicy: Delete
  storageClassName: default
```

Recreate the pv with the spec above.

The pv should be now Available:

```
NAME                                       CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS      CLAIM               STORAGECLASS   REASON    AGE
pvc-dbd2ac08-f32e-11e7-b70d-1212ccc85de2   10Gi       RWO           Delete          Available                        default                  5
```


Time to recreate the PVC with our old spec:

```yml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    pv.kubernetes.io/bind-completed: "yes"
    pv.kubernetes.io/bound-by-controller: "yes"
    volume.beta.kubernetes.io/storage-class: default
    volume.beta.kubernetes.io/storage-provisioner: kubernetes.io/aws-ebs
  creationTimestamp: 2018-01-06T22:13:44Z
  labels:
    app: acdclegacy-postgres
  name: acdclegacy-staging-data-acdclegacy-postgres-0
  namespace: acdc-legacy
#   resourceVersion: "23679"
#   selfLink: /api/v1/namespaces/acdc-legacy/persistentvolumeclaims/acdclegacy-staging-data-acdclegacy-postgres-0
#   uid: dbd2ac08-f32e-11e7-b70d-1212ccc85de2
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  volumeName: pvc-dbd2ac08-f32e-11e7-b70d-1212ccc85de2
status:
  #phase: Lost # YoursReplace Lost with Available :P
  phase: Available
```

Apply the manifest :D
