using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace ShipTrail
{
    [Serializable]
    public class ShipStop
    {
        public Vector3 positionToGo;
        public float timeToStay = 0f;
        public bool lookToTarget = true;

        public int targetToLook = 0;

        public bool waitUntilRotated=false;
        public float speed = 5f;
        public bool isReadyToContinue = true;
        public bool useCurve = false;
        public bool isPivot=false   ;
        [Header("Lock Rotation")]
        public bool lockX = false;
        public bool lockY = true;
        public bool lockZ = false;
    }

    public class TrailController : MonoBehaviour
    {
        private const float _shipSpeed = 10f;

        [SerializeField]
        public ShipStop[] shipStops;

        private Coroutine currentCoroutine;
        private bool _startTrip = false;
        private float _rotationSpeed = 0.2f;
        private List<Vector3> _positions = new List<Vector3>();



        public event Action<bool> OnStartTripChanged;

        public bool isTripStarted
        {
            get => _startTrip;
            set
            {
                if (_startTrip == value) return;
                _startTrip = value;
                OnStartTripChanged?.Invoke(_startTrip);
            }
        }

        private float timer = 0;
        private Coroutine _rotatingCoroutine=null;

        #region UNITY_CALLBACKS
        private void OnEnable()
        {
            OnStartTripChanged += StartTravelCoroutine;
        }

        private void OnDisable()
        {
            OnStartTripChanged -= StartTravelCoroutine;
        }

        private void Awake()
        {
            _positions.Clear();
            foreach (ShipStop stop in shipStops)
            {
                // Convierte la posición local del Inspector a posición de Mundo
                Vector3 worldPosition = transform.TransformPoint(stop.positionToGo);
                _positions.Add(worldPosition);
            }
        }

        void Update()
        {
#if UNITY_EDITOR
            if (isTripStarted)
            {
                timer += Time.deltaTime;
            }
#endif
        }
        #endregion

        public void StartTrip()
        {
            Debug.Log("Trip started");
            isTripStarted = true;
        }

        #region COROUTINES

        private IEnumerator TravelThrough()
        {
            for (int i = 0; i < shipStops.Length; i++)
            {
                ShipStop currentStop = shipStops[i];
                if (currentStop.isPivot) continue;
                Vector3 targetPosition = _positions[i];

                float speed = currentStop.speed > 0 ? currentStop.speed : _shipSpeed;

                Vector3 nextPosition = Vector3.zero;
                if (currentStop.targetToLook == 0)
                {
                    nextPosition = _positions[i + 1];
                }
                else
                {
                    nextPosition = _positions[currentStop.targetToLook];
                }

               
                if (!currentStop.useCurve)
                {
                   
                    yield return StartCoroutine(GoToPosition(targetPosition, speed));

                }
                else
                {
                    Vector3 startPosition = transform.position;
                    Vector3 pivotPosition = targetPosition;
                    if (!shipStops[i + 1].isPivot) shipStops[i + 1].isPivot = true;
                    Vector3 newTargetPosition = _positions[i+2];
                    //if (currentStop.lookToTarget) StartCoroutine(RotateToPosition(nextPosition, x: currentStop.lockX, y: currentStop.lockY, z: currentStop.lockZ));
                    yield return StartCoroutine(GoToPositionWithCurve(startPosition,pivotPosition,newTargetPosition,speed));
                }

                // 2. Rotar hacia el siguiente punto si existe
                if (_rotatingCoroutine == null)
                {
                    if (currentStop.lookToTarget && (i + 1) < shipStops.Length)
                    {
                        
                        if (currentStop.waitUntilRotated)
                        {

                            yield return StartCoroutine(RotateToPosition(nextPosition, x: currentStop.lockX, y: currentStop.lockY, z: currentStop.lockZ));
                            
                        }else
                        {
                            StartCoroutine(RotateToPosition(nextPosition,x:currentStop.lockX, y: currentStop.lockY,z:currentStop.lockZ));
                        }
                    }
                }

                // 3. Esperar tiempo de permanencia
                if (currentStop.isReadyToContinue)
                {
                    if (currentStop.timeToStay > 0)
                    {
                        yield return new WaitForSeconds(currentStop.timeToStay);
                    }
                }
                else
                {
                    yield return new WaitUntil(() => currentStop.isReadyToContinue);
                }
            }
        }

        private IEnumerator GoToPosition(Vector3 targetPosition, float speed)
        {
            while (Vector3.Distance(transform.position, targetPosition) > 0.05f)
            {
                transform.position = Vector3.MoveTowards(
                    transform.position,
                    targetPosition,
                    speed * Time.deltaTime
                );
                yield return null;
            }
            transform.position = targetPosition; // Ajuste fino final
        }
        private IEnumerator GoToPositionWithCurve(Vector3 startPosition, Vector3 pivotPosition, Vector3 targetPosition, float speed)
        {
            
            float estimatedDistance = Vector3.Distance(startPosition, pivotPosition) +
                Vector3.Distance(pivotPosition, targetPosition);
            float duration = estimatedDistance / speed;
            float time = 0f;
            while (Vector3.Distance(transform.position, targetPosition) > 0.05f)
            {
                time += Time.deltaTime;
                float t = Mathf.Clamp01(time / duration);


                transform.position = (1-t)*(1-t)*startPosition+
                    2*(1-t)*t*pivotPosition+(t*t)*targetPosition;
                yield return null;

                Vector3 tangent = 2f * (1f - t) * (pivotPosition - startPosition) +
                          2f * t * (targetPosition - pivotPosition);

                tangent.y = 0;
                if (tangent.sqrMagnitude > 0.0001f)
                {
                    Quaternion targetRotation = Quaternion.LookRotation(tangent);

                    // Suavizado suave frame a frame para evitar giros bruscos
                    transform.rotation = Quaternion.Slerp(transform.rotation, targetRotation, Time.deltaTime * 8f);
                }
            }
            transform.position = targetPosition; // Ajuste fino final
        }
        private IEnumerator RotateToPosition(Vector3 targetPosition,bool x,bool y,bool z)
        {
            Vector3 direction = targetPosition - transform.position;
            if(x)direction.x = 0; 
            if(y)direction.y = 0; 
            if(z)direction.z = 0; 
            
            // Evitar Vector3.zero para no corromper la rotación del Quaternion
            if (direction.sqrMagnitude < 0.0001f) yield break;

            Quaternion targetRotation = Quaternion.LookRotation(direction);

            while (Quaternion.Angle(transform.rotation, targetRotation) > 0.0001f)
            {
                transform.rotation = Quaternion.Slerp(
                    transform.rotation,
                    targetRotation,
                    Time.deltaTime * _rotationSpeed
                );
                yield return null;
            }

            transform.rotation = targetRotation; // Asignar la rotación exacta al finalizar
            _rotatingCoroutine=null;
        }

        #endregion

        #region HELPERS

        private void StartTravelCoroutine(bool isTraveling)
        {
            if (!isTraveling) return;
            if (currentCoroutine != null) StopCoroutine(currentCoroutine);
            currentCoroutine = StartCoroutine(TravelThrough());
        }

        private void OnDrawGizmos()
        {
            if (shipStops == null || shipStops.Length == 0) return;

            for (int i = 0; i < shipStops.Length - 1; i++)
            {
#if UNITY_EDITOR
                Vector3 startLinePosition = Application.isPlaying && _positions.Count > i ?
                    _positions[i] : transform.TransformPoint(shipStops[i].positionToGo);

                Vector3 finishLinePosition = Application.isPlaying && _positions.Count > (i + 1) ?
                    _positions[i + 1] : transform.TransformPoint(shipStops[i + 1].positionToGo);

                Gizmos.color = Color.cyan;
                Gizmos.DrawLine(startLinePosition, finishLinePosition);
                Gizmos.DrawSphere(startLinePosition, 0.2f);
#endif
            }
        }
        #endregion
    }
}