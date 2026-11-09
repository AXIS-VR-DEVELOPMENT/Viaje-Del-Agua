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
        public bool waitUntilRotated = false;
        public float speed = 5f;
        public bool isReadyToContinue = true;
        public bool useCurve = false;
        public bool isPivot = false;

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
        [SerializeField]
        private bool _startTrip = false;

        // Velocidad de giro en grados por segundo para giros rectos
        private float _rotationDegreesPerSec = 180f;
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

#if UNITY_EDITOR
        private float timer = 0;
#endif

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
            UpdatePositionsList();
        }

        private void UpdatePositionsList()
        {
            _positions.Clear();
            foreach (ShipStop stop in shipStops)
            {
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
            UpdatePositionsList();

            for (int i = 0; i < shipStops.Length; i++)
            {
                ShipStop currentStop = shipStops[i];

                // Si esta parada se marcó manualmente como pivote, se omite el tramo recto hacia ella
                if (currentStop.isPivot) continue;

                Vector3 targetPosition = _positions[i];
                float speed = currentStop.speed > 0 ? currentStop.speed : _shipSpeed;

                if (!currentStop.useCurve)
                {
                    // 1. Desplazamiento en línea recta a la parada i
                    yield return StartCoroutine(GoToPosition(targetPosition, speed));

                    // 2. Rotación hacia el siguiente objetivo (solo en tramos rectos)
                    if (currentStop.lookToTarget && i + 1 < _positions.Count)
                    {
                        Vector3 nextPosition = (currentStop.targetToLook > 0 && currentStop.targetToLook < _positions.Count)
                            ? _positions[currentStop.targetToLook]
                            : _positions[i + 1];

                        if (currentStop.waitUntilRotated)
                        {
                            yield return StartCoroutine(RotateToPosition(nextPosition, currentStop.lockX, currentStop.lockY, currentStop.lockZ));
                        }
                        else
                        {
                            StartCoroutine(RotateToPosition(nextPosition, currentStop.lockX, currentStop.lockY, currentStop.lockZ));
                        }
                    }
                }
                else
                {
                    // Validación de paradas requeridas: i (Inicio), i+1 (Pivote), i+2 (Llegada)
                    if (i + 2 >= _positions.Count) continue;

                    // A. Llegar primero a la parada i (Inicio de curva)
                    yield return StartCoroutine(GoToPosition(targetPosition, speed));

                    // B. Definir puntos de la Bézier cuadrática
                    Vector3 startPosition = targetPosition;        // Parada i
                    Vector3 pivotPosition = _positions[i + 1];      // Parada i+1
                    Vector3 endPosition = _positions[i + 2];        // Parada i+2

                    // C. Recorrer la curva orientándose suavemente hacia la tangente
                    yield return StartCoroutine(GoToPositionWithCurve(startPosition, pivotPosition, endPosition, speed));

                    // D. Avanzar un índice extra para omitir la parada pivote (i+1) en la siguiente iteración
                    i++;
                }

                // 3. Tiempo de permanencia al llegar al destino
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
            transform.position = targetPosition;
        }

        private IEnumerator GoToPositionWithCurve(Vector3 startPosition, Vector3 pivotPosition, Vector3 targetPosition, float speed)
        {
            float estimatedDistance = Vector3.Distance(startPosition, pivotPosition) + Vector3.Distance(pivotPosition, targetPosition);
            float duration = speed > 0 ? estimatedDistance / speed : 1f;
            float time = 0f;

            while (time < duration)
            {
                time += Time.deltaTime;
                float t = Mathf.Clamp01(time / duration);

                // Posición según Bézier cuadrática
                transform.position = (1f - t) * (1f - t) * startPosition +
                                     2f * (1f - t) * t * pivotPosition +
                                     (t * t) * targetPosition;

                // Rotación suave alineada a la tangente del movimiento
                Vector3 tangent = 2f * (1f - t) * (pivotPosition - startPosition) +
                                  2f * t * (targetPosition - pivotPosition);

                tangent.y = 0;
                if (tangent.sqrMagnitude > 0.0001f)
                {
                    Quaternion targetRotation = Quaternion.LookRotation(tangent);
                    transform.rotation = Quaternion.Slerp(transform.rotation, targetRotation, Time.deltaTime * 10f);
                }

                yield return null;
            }

            transform.position = targetPosition;
        }

        private IEnumerator RotateToPosition(Vector3 targetPosition, bool lockX, bool lockY, bool lockZ)
        {
            Vector3 direction = targetPosition - transform.position;
            if (lockX) direction.x = 0;
            if (lockY) direction.y = 0;
            if (lockZ) direction.z = 0;

            if (direction.sqrMagnitude < 0.001f) yield break;

            Quaternion targetRotation = Quaternion.LookRotation(direction);

            while (Quaternion.Angle(transform.rotation, targetRotation) > 0.5f)
            {
                transform.rotation = Quaternion.RotateTowards(
                    transform.rotation,
                    targetRotation,
                    _rotationDegreesPerSec * Time.deltaTime
                );
                yield return null;
            }

            transform.rotation = targetRotation;
        }

        #endregion

        #region HELPERS

        private Vector3 GetStopWorldPosition(int index)
        {
            if (index < 0 || index >= shipStops.Length) return transform.position;

            if (Application.isPlaying && _positions.Count > index)
                return _positions[index];

            return transform.TransformPoint(shipStops[index].positionToGo);
        }

        private Vector3 GetQuadraticBezierPoint(Vector3 p0, Vector3 p1, Vector3 p2, float t)
        {
            float u = 1f - t;
            return (u * u * p0) + (2f * u * t * p1) + (t * t * p2);
        }

        private void OnDrawGizmos()
        {
            if (shipStops == null || shipStops.Length == 0) return;

            for (int i = 0; i < shipStops.Length; i++)
            {
                Vector3 currentPos = GetStopWorldPosition(i);

                Gizmos.color = shipStops[i].isPivot ? Color.yellow : (shipStops[i].useCurve ? Color.magenta : Color.cyan);
                Gizmos.DrawSphere(currentPos, 0.25f);

                // Si la parada i inicia curva: i = Inicio, i+1 = Pivote, i+2 = Destino
                if (shipStops[i].useCurve && i + 2 < shipStops.Length)
                {
                    Vector3 p0 = currentPos;
                    Vector3 p1 = GetStopWorldPosition(i + 1);
                    Vector3 p2 = GetStopWorldPosition(i + 2);

                    // Guías visuales translúcidas hacia el pivote
                    Gizmos.color = new Color(1f, 0.92f, 0.016f, 0.4f);
                    Gizmos.DrawLine(p0, p1);
                    Gizmos.DrawLine(p1, p2);

                    // Renderizado verde de la curva Bézier
                    Gizmos.color = Color.green;
                    int segments = 20;
                    Vector3 previousPoint = p0;

                    for (int step = 1; step <= segments; step++)
                    {
                        float t = step / (float)segments;
                        Vector3 currentPoint = GetQuadraticBezierPoint(p0, p1, p2, t);
                        Gizmos.DrawLine(previousPoint, currentPoint);
                        previousPoint = currentPoint;
                    }
                }
                else if (i < shipStops.Length - 1 && !shipStops[i].isPivot && !shipStops[i].useCurve)
                {
                    Vector3 nextPos = GetStopWorldPosition(i + 1);
                    Gizmos.color = Color.cyan;
                    Gizmos.DrawLine(currentPos, nextPos);
                }
            }
        }

        private void StartTravelCoroutine(bool isTraveling)
        {
            if (!isTraveling) return;
            if (currentCoroutine != null) StopCoroutine(currentCoroutine);
            currentCoroutine = StartCoroutine(TravelThrough());
        }

        #endregion
    }
}