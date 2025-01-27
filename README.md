# Computer Vision Annotation Tool (CVAT) - Bossa Nova Fork

- [Official CVAT Repo](https://github.com/opencv/cvat)
- [CVAT documentation](https://opencv.github.io/cvat/docs)

# Building CVAT

To build new cvat-server and cvat-ui images from the BossaNova cvat repo:

```
git clone https://github.com/BossaNova/cvat.git
cd cvat
docker-compose -f docker-compose.no-infra.yml -f docker-compose.dev.yml build
```

To push to GCP artifact registry for use in the cloud: https://cloud.google.com/artifact-registry/docs/docker/pushing-and-pulling

# Running CVAT in Bossa Nova GCP

- Docker and other pre-reqs come installed in the Compute Engine VMs
- docker-compose.no-infra.yaml (in the repo root) will run everything using the images in Bossa Nova GCP artifact registry. It does not run postgres or redis, as there are managed instances in GCP for those.
- Endpoints for managed Postgres and Redis instances need to be configured as environment variables
  - CVAT_REDIS_HOST - url of redis instance
  - CVAT_POSTGRES_HOST - url of postgres instance
  - CVAT_POSTGRES_DBNAME - defaults to 'cvat' if not set
  - CVAT_POSTGRES_USER - defaults to 'root' if not set
  - CVAT_POSTGRES_PASSWORD - defaults to '' if not set
  - CVAT_POSTGRES_PORT - defaults to 5432 if not set (the postgres default)

A theoretical startup script to run everything:
```
export CVAT_REDIS_HOST=whatever
export CVAT_POSTGRES_HOST=whatever
cd ~
git clone https://github.com/BossaNova/cvat.git
cd cvat
docker-compose -f docker-compose.no-infra.yml up
```

We can docker-compose up/down just the cvat-ui service to deploy new versions

# Changes made to CVAT for Bossa Nova

## UX changes:
  - multiselect
    - select objects by clicking on them instead of auto-selection on mouseover
    - select multiple objects with shift+click
    - select multiple objects with click-drag selection box
    - keyboard shortcuts apply to all selected objects
    - canvas context menu now shows all selected objects
      - added a 'change label' field for changing the label of all selected objects
  - grouped object list
    - object list is grouped by label
    - label-item component re-used as a header for each group of objects
    - label groups can be collapsed
    - expand/collapse all affects the label groups too

## Technical changes to React app

#### redux changes:
- state:
  - state.annotations.activatedStateID (number) changed to activatedStateIDs (number[])
  - added state.annotations.collapsedLabels
  - added state.job.labelShortcuts
  - state.canvas.contextmenu.clientID (number) changed to state.canvas.contextmenu.clientIDs (number[])
- actions:
  - ACTIVATE_OBJECT changed to ACTIVATE_OBJECTS
  - DEACTIVATE_OBJECTS added
  - COLLAPSE_LABEL_GROUPS added
  - COLLAPSE_ALL added
  - UPDATE_LABEL_SHORTCUTS added

#### major component changes:
- label-item
  - converted a functional component
  - label shortcuts are in redux state now instead of local component state to enable the label-item to be re-used in the object list
- object-list
  - displays grouped objects instead of a flat object list

#### canvas changes
- everything is based on multiple activate objects instead of only 1
- added SelectionBoxHandler for selection box behavior, refactored out BoxSelector class to handle drawing boxes in a reusable way