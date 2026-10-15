using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerController : MonoBehaviour
{
    //TODO: CHange to private
    public Transform playerTransform;
    public Transform startPosition; 

    private void Awake()
    {
        if (playerTransform == null)
        {
            playerTransform=GameObject.Find("Player").
                GetComponent<Transform>();
        }
        if (startPosition == null)
        {
            startPosition = GameObject.Find("PlayerStartPosition").
                GetComponent<Transform>();
        }
    }
    private void Start()
    {
        if(playerTransform!=null && startPosition!=null)
        {

            playerTransform.position=startPosition.position;
            playerTransform.rotation=startPosition.rotation;
        }    
    }

}
