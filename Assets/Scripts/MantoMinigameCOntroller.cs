using UnityEngine;
using Fluvio;
using ShipTrail;
using System.Collections;
public class MantoMinigameController : MonoBehaviour
{
    
    public bool isGameDone=false;
    public FluvioController hidrolito;
    public TrailController ship;

    public Canvas frogTextbox;

    public int stopedShipPosition=7;

    public string[] frogText = new string[2];
    private int itemCounter=0;
    //The final point in which the object travel 
    private Collider goalCollision;

    private SpeechBubbleAnimator speechAnimator;
#region UNITY_CALLBACKS
    void Awake()
    {
        if(!goalCollision)goalCollision=
            GetComponent<Collider>();;
        if(!hidrolito)
            hidrolito=GameObject.Find("Fluvi-o").
                GetComponent<FluvioController>();
        if(!ship)
        {
            ship=GameObject.Find("Anfinave").GetComponent<TrailController>();
        }
        if (frogTextbox!=null)
        {
            speechAnimator=frogTextbox.gameObject.GetComponent<SpeechBubbleAnimator>();
        }
        isGameDone=false;
        itemCounter=0;
    }

    void Start()
    {
        speechAnimator.AnimateOut();
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
    private IEnumerator changeText(string text)
    {
        WaitForSeconds timeForChange = new WaitForSeconds(2f);
        
        speechAnimator.AnimateOut();
        yield return timeForChange;
        speechAnimator.AnimateIn(text);


    }
    private void EndGame()
    {
        isGameDone=true;
        hidrolito.ResumeAnimation();
        ship.shipStops[stopedShipPosition].isReadyToContinue=true;
        speechAnimator.AnimateOut();
    }
    private void AddObjectToFilter(GameObject antiGravityObject)
    {
        antiGravityObject.SetActive(false);
        StopAllCoroutines();
        if(itemCounter<frogText.Length)StartCoroutine(changeText(frogText[itemCounter]));
        itemCounter++;


    }
    
#endregion

}
