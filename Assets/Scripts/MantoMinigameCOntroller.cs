using UnityEngine;
using Fluvio;
using ShipTrail;
public class MantoMinigameController : MonoBehaviour
{
    
    public bool isGameDone=false;
    public FluvioController hidrolito;
    public TrailController ship;

    public int stopedShipPosition=7;
    private int itemCounter=0;
    //The final point in which the object travel 
    private Collider goalCollision;
#region UNITY_CALLBACKS
    void Awake()
    {
        if(!goalCollision)goalCollision=
            GetComponent<Collider>();;
        if(!hidrolito)
            hidrolito=GameObject.Find("Fluvi-o").
                GetComponent<FluvioController>();
        if(!ship)ship=GameObject.Find("Anfinave").GetComponent<TrailController>();
        isGameDone=false;
        itemCounter=0;
    }

    void Start()
    {
        
    }
    void Update()
    {
        
    }
    void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("GrabbableObject"))
        {
            GameObject antiGravityObject=other.gameObject;
            AddObjectToFilter(antiGravityObject);
            if (itemCounter == 3)
            {
                EndGame();
            }
        }
    }
    #endregion

    #region CALLBACKS
    private void EndGame()
    {
        isGameDone=true;
        hidrolito.ResumeAnimation();
        ship.shipStops[stopedShipPosition].isReadyToContinue=true;
    }
    private void AddObjectToFilter(GameObject antiGravityObject)
    {
        antiGravityObject.SetActive(false);
        itemCounter++;

    }
    
#endregion

}
