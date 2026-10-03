using Oculus.Platform.Models;
using System;
using System.Collections;
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
    }
    public class TrailController : MonoBehaviour
    {
        public const float _shipSpeed=5f;
        [SerializeField]
        private ShipStop[] shipStops;


        #region UNITY_CALLBACKS
        // Start is called once before the first execution of Update after the MonoBehaviour is created

        private void Awake()
        {
            
        }
        void Start()
        {
            StartCoroutine(TravelThrough());
        }

        // Update is called once per frame
        void Update()
        {

        }
        #endregion

        #region FUNCTIONS
        private IEnumerator TravelThrough()
        {
            foreach(ShipStop currentStop in shipStops)
            {
                Vector3 position = currentStop.positionToGo;
                float speed = currentStop.speed;
                yield return StartCoroutine(GoToPosition(position,speed));
                yield return new WaitForSeconds(currentStop.timeToStay);
            }
        }
        private IEnumerator GoToPosition(Vector3 targetPosition,float speed=_shipSpeed)
        {
            while (Vector3.Distance(transform.position,targetPosition)>0.05f)
            {
            Vector3 currentPosition = transform.position;
            transform.position = Vector3.MoveTowards(currentPosition,targetPosition,speed*Time.deltaTime);
            yield return null;
            }
            

        }
        #endregion
        #region HELPERS
        private void OnDrawGizmos()
        {
            if (shipStops==null) return;

            for(int i=0;i<shipStops.Length;i++)
            {
#if UNITY_EDITOR
                if ((i + 1) >= shipStops.Length) return;
                Vector3 startLinePosition = 
                    transform.TransformPoint(shipStops[i].positionToGo);
                Vector3 finishLinePosition = 
                    transform.TransformPoint(shipStops[i+1].positionToGo);

                Gizmos.DrawLine(startLinePosition, finishLinePosition);
#endif
            }


        }
        #endregion
    }
}
