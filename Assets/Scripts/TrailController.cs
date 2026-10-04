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
        public float speed = 5f;
        public bool isReadyToContinue = true;

    }
    public class TrailController : MonoBehaviour
    {
        private Vector3[] drawPositions;
        public const float _shipSpeed = 5f;
        [SerializeField]
        private ShipStop[] shipStops;
        private Coroutine currentCourutine;
        private bool _startTrip = false;
        private float _rotationSpeed = 5f;
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

        #region UNITY_CALLBACKS
        // Start is called once before the first execution of Update after the MonoBehaviour is created
        private void OnEnable()
        {
            OnStartTripChanged += StartTravelCourutine;
        }
        private void OnDisable()
        {
            OnStartTripChanged -= StartTravelCourutine;
        }
        private void Awake()
        {

            foreach (ShipStop stop in shipStops)
            {
                Vector3 localPostion = transform.TransformPoint(stop.positionToGo);
                _positions.Add(localPostion);
            }

        }
        void Start()
        {
            isTripStarted = true;
        }

        // Update is called once per frame
        void Update()
        {
#if UNITY_EDITOR
        if(isTripStarted)
        {
            timer += Time.deltaTime;
        }
#endif
        }
        #endregion

        #region COURUTINES


        private IEnumerator TravelThrough()
        {
            float time = 0;
            for (int i = 0; i < shipStops.Length; i++)
            {

                Debug.Log($"Current Position: {i}\nTime: {timer}");
                ShipStop currentStop = shipStops[i];
                ShipStop nextStop = null;
                Vector3 position = _positions[i];
                Vector3 nextPosition = Vector3.zero;

                if (i + 1 < shipStops.Length)
                {
                    nextStop = shipStops[i + 1];
                    nextPosition = _positions[i + 1];
                }
                float speed = currentStop.speed;
                yield return StartCoroutine(GoToPosition(position, speed));

                if (currentStop.lookToTarget && nextStop != null)
                {

                    yield return StartCoroutine(RotateToPosition(nextPosition));
                }
                if (currentStop.isReadyToContinue)
                {
                    if (currentStop.timeToStay > 0)
                    {
                        yield return new
                            WaitForSeconds(currentStop.timeToStay);
                    }
                    else
                    {
                        yield return null;
                    }
                }
                else
                {
                    yield return new WaitUntil(() =>
                        currentStop.isReadyToContinue);
                }
            }
        }
        private IEnumerator GoToPosition(Vector3 targetPosition, float speed = _shipSpeed)
        {
            while (Vector3.Distance(transform.position, targetPosition) > 0.05f)
            {
                Vector3 currentPosition = transform.position;
                transform.position =
                        Vector3.
                        MoveTowards(currentPosition, targetPosition,
                        (speed != 0 ? speed : _shipSpeed) * Time.deltaTime);
                yield return null;
            }


        }
        private IEnumerator RotateToPosition(Vector3 TargetPosition)
        {
            if (TargetPosition == Vector3.zero) yield return null;
            Vector3 direction = TargetPosition - transform.position;
            if (direction == Vector3.zero) yield return null;
            direction.y = 0;
            Quaternion targetDirection = Quaternion.LookRotation(direction);
            float diference = Vector3.Angle(transform.forward, direction.normalized);
            while (diference > 0.05f)
            {
                diference = Vector3.Angle(transform.forward, direction.normalized);
                transform.rotation = Quaternion.Slerp(transform.rotation, targetDirection, Time.deltaTime * _rotationSpeed);
                yield return null;
            }

        }
        #endregion
        #region HELPERS


        private void StartTravelCourutine(bool isTraveling)
        {
            if (!isTraveling) return;
            currentCourutine = StartCoroutine(TravelThrough());
        }
        private void OnDrawGizmos()
        {
            if (shipStops == null) return;

            for (int i = 0; i < shipStops.Length; i++)
            {


#if UNITY_EDITOR
                if ((i + 1) >= shipStops.Length) return;
                Vector3 finishLinePosition, startLinePosition;
                if (Application.isPlaying)
                {
                    
                    startLinePosition =
                        _positions[i];
                        
                    finishLinePosition =
                        _positions[i+1];
                }
                else
                {
                    startLinePosition =
                        transform.TransformPoint(shipStops[i].positionToGo);
                    finishLinePosition = 
                        transform.TransformPoint(shipStops[i+1].positionToGo);
                }

                Gizmos.DrawLine(startLinePosition, finishLinePosition);
#endif
            }


        }
        #endregion
    }
}
